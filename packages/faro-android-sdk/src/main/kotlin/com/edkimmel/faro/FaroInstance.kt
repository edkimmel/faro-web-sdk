package com.edkimmel.faro

import android.app.Application
import android.os.Build
import android.util.DisplayMetrics
import com.edkimmel.faro.api.models.*
import com.edkimmel.faro.instrumentations.Instrumentation
import com.edkimmel.faro.instrumentations.anr.AnrInstrumentation
import com.edkimmel.faro.instrumentations.crash.CrashInstrumentation
import com.edkimmel.faro.instrumentations.lifecycle.AppLifecycleInstrumentation
import com.edkimmel.faro.internal.Clock
import com.edkimmel.faro.internal.InternalLogger
import com.edkimmel.faro.persistence.DiskBuffer
import com.edkimmel.faro.session.SessionManager
import com.edkimmel.faro.session.SessionStore
import com.edkimmel.faro.transport.*
import java.io.File

class FaroInstance internal constructor(
    val application: Application,
    val config: FaroConfig,
    private val logger: InternalLogger
) {
    private val sessionManager: SessionManager
    private val diskBuffer: DiskBuffer
    private val httpTransport: HttpTransport
    private val diskBufferTransport: DiskBufferTransport
    private val batchExecutor: BatchExecutor
    private val instrumentations = java.util.concurrent.CopyOnWriteArrayList<Instrumentation>()

    @Volatile
    private var isPaused = false

    @Volatile
    private var currentUser: MetaUser? = config.user

    @Volatile
    private var currentView: MetaView? = null

    companion object {
        const val SDK_NAME = "faro-android-sdk"
        const val SDK_VERSION = "1.0.0"
    }

    init {
        val sessionStore = SessionStore(application)
        sessionManager = SessionManager(config.sessionTracking, sessionStore, logger)

        diskBuffer = DiskBuffer(
            baseDir = File(application.cacheDir, "faro"),
            config = config.diskBufferConfig,
            logger = logger
        )

        httpTransport = HttpTransport(
            collectorUrl = config.collectorUrl,
            apiKey = config.apiKey,
            logger = logger
        )

        diskBufferTransport = DiskBufferTransport(
            diskBuffer = diskBuffer,
            httpTransport = httpTransport,
            logger = logger,
            appContext = application.applicationContext
        )

        batchExecutor = BatchExecutor(
            config = config.batchConfig,
            logger = logger,
            onFlush = { items -> flushItems(items) }
        )
    }

    internal fun start() {
        logger.info("Starting Faro SDK")

        // Start session
        sessionManager.start()

        // Start disk buffer transport (sends pending crashes/signals)
        diskBufferTransport.start()

        // Install instrumentations
        if (config.enableLifecycleTracking) {
            installInstrumentation(AppLifecycleInstrumentation())
        }

        if (config.enableCrashReporting) {
            installInstrumentation(CrashInstrumentation())
        }

        if (config.enableAnrDetection) {
            installInstrumentation(AnrInstrumentation())
        }

        logger.info("Faro SDK started")
    }

    fun installInstrumentation(instrumentation: Instrumentation) {
        instrumentation.install(this)
        instrumentations.add(instrumentation)
        logger.debug("Installed instrumentation: ${instrumentation.name}")
    }

    // ---- Public API ----

    fun pushLog(
        message: String,
        level: LogLevel = LogLevel.LOG,
        context: Map<String, String>? = null,
        traceContext: TraceContext? = null
    ) {
        if (isPaused || !sessionManager.isSampled()) return

        if (shouldIgnoreError(message)) return

        val event = LogEvent(
            message = message,
            level = level,
            timestamp = Clock.nowTimestamp(),
            context = context,
            trace = traceContext
        )

        enqueue(TransportItemType.LOG, event)
    }

    fun pushError(
        error: Throwable,
        context: Map<String, String>? = null,
        traceContext: TraceContext? = null
    ) {
        pushError(
            type = error.javaClass.name,
            value = error.message ?: "Unknown error",
            stacktrace = parseThrowableStacktrace(error),
            context = context,
            traceContext = traceContext
        )
    }

    fun pushError(
        type: String,
        value: String,
        stacktrace: Stacktrace? = null,
        context: Map<String, String>? = null,
        traceContext: TraceContext? = null
    ) {
        if (isPaused || !sessionManager.isSampled()) return

        if (shouldIgnoreError(value)) return

        val event = ExceptionEvent(
            type = type,
            value = value,
            timestamp = Clock.nowTimestamp(),
            stacktrace = stacktrace,
            context = context,
            trace = traceContext
        )

        enqueue(TransportItemType.EXCEPTION, event)
    }

    fun pushMeasurement(
        type: String,
        values: Map<String, Double>,
        context: Map<String, String>? = null,
        traceContext: TraceContext? = null
    ) {
        if (isPaused || !sessionManager.isSampled()) return

        val event = MeasurementEvent(
            type = type,
            values = values,
            timestamp = Clock.nowTimestamp(),
            context = context,
            trace = traceContext
        )

        enqueue(TransportItemType.MEASUREMENT, event)
    }

    fun pushEvent(
        name: String,
        attributes: Map<String, String>? = null,
        domain: String? = null,
        traceContext: TraceContext? = null
    ) {
        if (isPaused || !sessionManager.isSampled()) return

        val event = EventEvent(
            name = name,
            timestamp = Clock.nowTimestamp(),
            domain = domain ?: config.eventDomain,
            attributes = attributes,
            trace = traceContext
        )

        enqueue(TransportItemType.EVENT, event)
    }

    fun setUser(user: MetaUser?) {
        currentUser = user
    }

    fun resetUser() {
        currentUser = null
    }

    fun setView(viewName: String) {
        currentView = MetaView(name = viewName)
    }

    fun setSession(sessionId: String) {
        sessionManager.setSessionId(sessionId)
    }

    fun getSessionId(): String = sessionManager.getSessionId()

    fun pause() {
        isPaused = true
        batchExecutor.isPaused = true
    }

    fun unpause() {
        isPaused = false
        batchExecutor.isPaused = false
    }

    fun shutdown() {
        instrumentations.forEach { it.uninstall() }
        instrumentations.clear()
        batchExecutor.shutdown()
        diskBufferTransport.shutdown()
    }

    // ---- Internal ----

    /** Replay a pre-init buffered log with its original timestamp preserved. */
    internal fun replayLog(message: String, level: LogLevel, context: Map<String, String>?, timestamp: String) {
        val event = LogEvent(message = message, level = level, timestamp = timestamp, context = context)
        enqueue(TransportItemType.LOG, event)
    }

    /** Replay a pre-init buffered error with its original timestamp preserved. */
    internal fun replayError(type: String, value: String, stacktrace: Stacktrace?, context: Map<String, String>?, timestamp: String) {
        val event = ExceptionEvent(type = type, value = value, timestamp = timestamp, stacktrace = stacktrace, context = context)
        enqueue(TransportItemType.EXCEPTION, event)
    }

    /** Replay a pre-init buffered measurement with its original timestamp preserved. */
    internal fun replayMeasurement(type: String, values: Map<String, Double>, context: Map<String, String>?, timestamp: String) {
        val event = MeasurementEvent(type = type, values = values, timestamp = timestamp, context = context)
        enqueue(TransportItemType.MEASUREMENT, event)
    }

    /** Replay a pre-init buffered event with its original timestamp preserved. */
    internal fun replayEvent(name: String, attributes: Map<String, String>?, domain: String?, timestamp: String) {
        val event = EventEvent(name = name, timestamp = timestamp, domain = domain ?: config.eventDomain, attributes = attributes)
        enqueue(TransportItemType.EVENT, event)
    }

    internal fun writeCrashToDisk(exception: ExceptionEvent) {
        val body = TransportBody(
            meta = buildMeta(),
            exceptions = listOf(exception)
        )
        diskBuffer.writeCrash(body)
    }

    internal fun shouldIgnoreUrl(url: String): Boolean {
        if (url == config.collectorUrl) return true
        return config.ignoreUrls.any { it.containsMatchIn(url) }
    }

    private fun shouldIgnoreError(message: String): Boolean {
        return config.ignoreErrors.any { it.containsMatchIn(message) }
    }

    private fun enqueue(type: TransportItemType, payload: Any) {
        val item = TransportItem(
            type = type,
            payload = payload,
            meta = buildMeta()
        )

        // Apply beforeSend hook — user code, must not crash the host app
        val processedItem: TransportItem? = if (config.beforeSend != null) {
            try {
                config.beforeSend.invoke(item)
            } catch (e: Exception) {
                logger.error("beforeSend hook threw an exception, sending original item", e)
                item
            }
        } else {
            item
        }

        if (processedItem == null) {
            logger.debug("Signal dropped by beforeSend hook")
            return
        }

        batchExecutor.add(processedItem)
    }

    private fun flushItems(items: List<TransportItem>) {
        if (items.isEmpty()) return

        val meta = items.first().meta
        val logs = mutableListOf<LogEvent>()
        val exceptions = mutableListOf<ExceptionEvent>()
        val measurements = mutableListOf<MeasurementEvent>()
        val events = mutableListOf<EventEvent>()

        for (item in items) {
            when (item.type) {
                TransportItemType.LOG -> (item.payload as? LogEvent)?.let { logs.add(it) }
                    ?: logger.error("Unexpected payload type for log item, skipping")
                TransportItemType.EXCEPTION -> (item.payload as? ExceptionEvent)?.let { exceptions.add(it) }
                    ?: logger.error("Unexpected payload type for exception item, skipping")
                TransportItemType.MEASUREMENT -> (item.payload as? MeasurementEvent)?.let { measurements.add(it) }
                    ?: logger.error("Unexpected payload type for measurement item, skipping")
                TransportItemType.EVENT -> (item.payload as? EventEvent)?.let { events.add(it) }
                    ?: logger.error("Unexpected payload type for event item, skipping")
            }
        }

        val body = TransportBody(
            meta = meta,
            logs = logs.ifEmpty { null },
            exceptions = exceptions.ifEmpty { null },
            measurements = measurements.ifEmpty { null },
            events = events.ifEmpty { null }
        )

        diskBufferTransport.send(body)
    }

    private fun buildMeta(): Meta {
        return Meta(
            sdk = MetaSDK(
                name = SDK_NAME,
                version = SDK_VERSION,
                integrations = instrumentations.map {
                    MetaSDKIntegration(name = it.name)
                }
            ),
            app = config.app,
            user = currentUser,
            session = MetaSession(id = sessionManager.getSessionId()),
            view = currentView,
            device = buildDeviceMeta()
        )
    }

    private fun buildDeviceMeta(): MetaDevice {
        val displayMetrics = application.resources.displayMetrics
        return MetaDevice(
            platform = "android",
            osName = "Android",
            osVersion = Build.VERSION.RELEASE,
            deviceModel = Build.MODEL,
            deviceManufacturer = Build.MANUFACTURER,
            screenWidth = displayMetrics.widthPixels,
            screenHeight = displayMetrics.heightPixels,
            screenDensity = displayMetrics.density,
            isEmulator = isEmulator()
        )
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.contains("sdk_gphone")
                || Build.PRODUCT.contains("vbox86p")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu"))
    }

    private fun parseThrowableStacktrace(throwable: Throwable): Stacktrace {
        val frames = throwable.stackTrace.map { element ->
            ExceptionStackFrame(
                filename = element.fileName ?: "unknown",
                function = "${element.className}.${element.methodName}",
                lineno = element.lineNumber.takeIf { it > 0 },
                colno = null
            )
        }
        return Stacktrace(frames = frames)
    }
}
