package com.edkimmel.faro

import android.app.Application
import com.edkimmel.faro.api.models.LogLevel
import com.edkimmel.faro.api.models.Stacktrace
import com.edkimmel.faro.api.models.ExceptionStackFrame
import com.edkimmel.faro.internal.InternalLogger
import com.edkimmel.faro.persistence.PreInitBuffer
import com.edkimmel.faro.persistence.PreInitBufferConfig

/**
 * Faro Android SDK - Singleton entry point.
 *
 * Initialize once in your Application.onCreate():
 * ```kotlin
 * Faro.initialize(
 *     application = this,
 *     config = FaroConfig(
 *         collectorUrl = "https://your-collector.example.com/collect",
 *         app = MetaApp(name = "MyApp", version = "1.0.0")
 *     )
 * )
 * ```
 *
 * Signals can be sent at any time — before or after initialization:
 * ```kotlin
 * // These are buffered to disk if sent before initialize()
 * Faro.pushLog("App woke for background fetch")
 * Faro.pushEvent("background_update_check")
 *
 * // After initialize(), signals go directly through the SDK
 * Faro.pushLog("User tapped login")
 * ```
 *
 * Pre-init buffered signals are automatically replayed when initialize() is called.
 */
object Faro {
    @Volatile
    private var instance: FaroInstance? = null

    private val preInitBuffer = PreInitBuffer.getInstance()

    /**
     * Configure the pre-initialization buffer before the SDK is initialized.
     * Call this early (e.g., in Application.onCreate()) if you need custom buffer settings.
     *
     * @param application The Android Application instance (needed for cache directory)
     * @param config The pre-init buffer configuration
     */
    fun configurePreInitBuffer(application: Application, config: PreInitBufferConfig = PreInitBufferConfig()) {
        preInitBuffer.configure(application.cacheDir, config)
    }

    /**
     * Initialize the Faro SDK. Should be called once, typically in Application.onCreate().
     *
     * Any signals buffered before initialization are automatically replayed through
     * the SDK after startup completes.
     *
     * @param application The Android Application instance
     * @param config The Faro configuration
     * @return The initialized FaroInstance
     */
    fun initialize(application: Application, config: FaroConfig): FaroInstance {
        synchronized(this) {
            instance?.let { existing ->
                val logger = InternalLogger(config.internalLoggerLevel)
                logger.warn("Faro is already initialized. Returning existing instance.")
                return existing
            }

            // Ensure pre-init buffer has the cache dir configured
            val preInitConfig = config.preInitBufferConfig ?: PreInitBufferConfig()
            preInitBuffer.configure(application.cacheDir, preInitConfig)

            val logger = InternalLogger(config.internalLoggerLevel)
            val faroInstance = FaroInstance(application, config, logger)
            faroInstance.start()
            // Only set instance after start() succeeds
            instance = faroInstance

            // Replay any pre-init buffered signals
            replayPreInitBuffer(faroInstance, logger)

            return faroInstance
        }
    }

    /**
     * Get the initialized Faro instance, if available.
     *
     * @return The FaroInstance, or null if not yet initialized
     */
    fun getInstance(): FaroInstance? {
        return instance
    }

    /**
     * Check if Faro has been initialized.
     */
    fun isInitialized(): Boolean = instance != null

    /**
     * Shutdown and reset the Faro SDK. Primarily for testing.
     */
    fun reset() {
        synchronized(this) {
            instance?.shutdown()
            instance = null
        }
    }

    // ---- Convenience methods (buffer if not initialized, forward if initialized) ----

    /**
     * Push a log signal. Buffers to disk if the SDK is not yet initialized.
     */
    fun pushLog(
        message: String,
        level: LogLevel = LogLevel.LOG,
        context: Map<String, String>? = null
    ) {
        val inst = instance
        if (inst != null) {
            inst.pushLog(message = message, level = level, context = context)
        } else {
            preInitBuffer.bufferLog(message = message, level = level.name.lowercase(), context = context)
        }
    }

    /**
     * Push an error signal. Buffers to disk if the SDK is not yet initialized.
     */
    fun pushError(
        type: String,
        value: String,
        stacktrace: Stacktrace? = null,
        context: Map<String, String>? = null
    ) {
        val inst = instance
        if (inst != null) {
            inst.pushError(type = type, value = value, stacktrace = stacktrace, context = context)
        } else {
            val preInitSt = stacktrace?.let { st ->
                com.edkimmel.faro.persistence.PreInitStacktrace(
                    frames = st.frames.map { f ->
                        com.edkimmel.faro.persistence.PreInitStackFrame(
                            filename = f.filename,
                            function = f.function,
                            colno = f.colno,
                            lineno = f.lineno
                        )
                    }
                )
            }
            preInitBuffer.bufferError(type = type, value = value, stacktrace = preInitSt, context = context)
        }
    }

    /**
     * Push an error signal from a Throwable. Buffers to disk if the SDK is not yet initialized.
     */
    fun pushError(
        error: Throwable,
        context: Map<String, String>? = null
    ) {
        val inst = instance
        if (inst != null) {
            inst.pushError(error = error, context = context)
        } else {
            val frames = error.stackTrace.map { element ->
                com.edkimmel.faro.persistence.PreInitStackFrame(
                    filename = element.fileName ?: "unknown",
                    function = "${element.className}.${element.methodName}",
                    lineno = element.lineNumber.takeIf { it > 0 },
                    colno = null
                )
            }
            preInitBuffer.bufferError(
                type = error.javaClass.name,
                value = error.message ?: "Unknown error",
                stacktrace = com.edkimmel.faro.persistence.PreInitStacktrace(frames = frames),
                context = context
            )
        }
    }

    /**
     * Push a measurement signal. Buffers to disk if the SDK is not yet initialized.
     */
    fun pushMeasurement(
        type: String,
        values: Map<String, Double>,
        context: Map<String, String>? = null
    ) {
        val inst = instance
        if (inst != null) {
            inst.pushMeasurement(type = type, values = values, context = context)
        } else {
            preInitBuffer.bufferMeasurement(type = type, values = values, context = context)
        }
    }

    /**
     * Push a custom event. Buffers to disk if the SDK is not yet initialized.
     */
    fun pushEvent(
        name: String,
        attributes: Map<String, String>? = null,
        domain: String? = null
    ) {
        val inst = instance
        if (inst != null) {
            inst.pushEvent(name = name, attributes = attributes, domain = domain)
        } else {
            preInitBuffer.bufferEvent(name = name, attributes = attributes, domain = domain)
        }
    }

    // ---- Pre-init replay ----

    private fun replayPreInitBuffer(instance: FaroInstance, logger: InternalLogger) {
        val entries = preInitBuffer.readPendingEntries()
        if (entries.isEmpty()) return

        logger.info("Replaying ${entries.size} pre-init buffered signal(s)")

        for (entry in entries) {
            when (entry.signalType) {
                "log" -> entry.log?.let { data ->
                    instance.replayLog(
                        message = data.message,
                        level = LogLevel.fromString(data.level),
                        context = data.context,
                        timestamp = entry.timestamp
                    )
                }
                "exception" -> entry.exception?.let { data ->
                    val stacktrace = data.stacktrace?.let { st ->
                        Stacktrace(frames = st.frames.map { f ->
                            ExceptionStackFrame(
                                filename = f.filename,
                                function = f.function,
                                colno = f.colno,
                                lineno = f.lineno
                            )
                        })
                    }
                    instance.replayError(
                        type = data.type,
                        value = data.value,
                        stacktrace = stacktrace,
                        context = data.context,
                        timestamp = entry.timestamp
                    )
                }
                "measurement" -> entry.measurement?.let { data ->
                    instance.replayMeasurement(
                        type = data.type,
                        values = data.values,
                        context = data.context,
                        timestamp = entry.timestamp
                    )
                }
                "event" -> entry.event?.let { data ->
                    instance.replayEvent(
                        name = data.name,
                        attributes = data.attributes,
                        domain = data.domain,
                        timestamp = entry.timestamp
                    )
                }
                else -> logger.warn("Unknown pre-init signal type: ${entry.signalType}")
            }
        }

        preInitBuffer.clear()
        logger.info("Pre-init buffer replay complete")
    }
}
