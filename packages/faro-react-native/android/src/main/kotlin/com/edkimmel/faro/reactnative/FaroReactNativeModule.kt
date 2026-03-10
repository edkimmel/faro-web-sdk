package com.edkimmel.faro.reactnative

import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import com.facebook.react.bridge.*
import com.edkimmel.faro.Faro
import com.edkimmel.faro.FaroConfig
import com.edkimmel.faro.FaroInstance
import com.edkimmel.faro.api.models.*
import com.edkimmel.faro.internal.InternalLoggerLevel
import com.edkimmel.faro.session.SessionConfig
import com.edkimmel.faro.transport.BatchConfig
import kotlinx.serialization.json.*

class FaroReactNativeModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "FaroReactNative"

    companion object {
        private const val TAG = "FaroReactNative"
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = false
        explicitNulls = false
    }

    private var faroInstance: FaroInstance? = null

    @ReactMethod
    fun initialize(configJson: String, promise: Promise) {
        Log.d(TAG, "initialize() called")
        try {
            val config = parseConfig(configJson)
            Log.d(TAG, "Config parsed — collectorUrl=${config.collectorUrl}")
            val app = reactApplicationContext.applicationContext as android.app.Application
            faroInstance = Faro.initialize(app, config)
            Log.i(TAG, "Native SDK initialized successfully")
            promise.resolve(null)
        } catch (e: Exception) {
            Log.e(TAG, "initialize() failed: ${e.message}", e)
            promise.reject("FARO_INIT_ERROR", e.message, e)
        }
    }

    private fun ensureInstance(caller: String): FaroInstance? {
        val instance = faroInstance
        if (instance == null) {
            Log.w(TAG, "$caller called but native SDK not initialized — dropping signal")
        }
        return instance
    }

    @ReactMethod
    fun pushLog(level: String, message: String, context: String?, timestamp: String?) {
        val instance = ensureInstance("pushLog") ?: return
        Log.d(TAG, "pushLog(level=$level, message=${message.take(80)})")
        val ctx = context?.let { parseStringMap(it) }
        instance.pushLog(
            message = message,
            level = LogLevel.fromString(level),
            context = ctx
        )
    }

    @ReactMethod
    fun pushError(type: String, value: String, stacktrace: String?, context: String?) {
        val instance = ensureInstance("pushError") ?: return
        Log.d(TAG, "pushError(type=$type, value=${value.take(80)})")
        val ctx = context?.let { parseStringMap(it) }
        val st = stacktrace?.let { parseStacktrace(it) }
        instance.pushError(
            type = type,
            value = value,
            stacktrace = st,
            context = ctx
        )
    }

    @ReactMethod
    fun pushMeasurement(type: String, values: String, context: String?) {
        val instance = ensureInstance("pushMeasurement") ?: return
        Log.d(TAG, "pushMeasurement(type=$type, values=$values)")
        val parsedValues = parseDoubleMap(values)
        val ctx = context?.let { parseStringMap(it) }
        instance.pushMeasurement(
            type = type,
            values = parsedValues,
            context = ctx
        )
    }

    @ReactMethod
    fun pushEvent(name: String, attributes: String?, domain: String?) {
        val instance = ensureInstance("pushEvent") ?: return
        Log.d(TAG, "pushEvent(name=$name, domain=$domain)")
        val attrs = attributes?.let { parseStringMap(it) }
        instance.pushEvent(
            name = name,
            attributes = attrs,
            domain = domain
        )
    }

    @ReactMethod
    fun setUser(userJson: String) {
        val instance = ensureInstance("setUser") ?: return
        Log.d(TAG, "setUser()")
        val user = parseUser(userJson)
        instance.setUser(user)
    }

    @ReactMethod
    fun resetUser() {
        Log.d(TAG, "resetUser()")
        faroInstance?.resetUser()
    }

    @ReactMethod
    fun setSession(sessionId: String) {
        Log.d(TAG, "setSession(id=$sessionId)")
        faroInstance?.setSession(sessionId)
    }

    @ReactMethod
    fun setView(viewName: String) {
        Log.d(TAG, "setView(name=$viewName)")
        faroInstance?.setView(viewName)
    }

    @ReactMethod
    fun setPage(pageJson: String) {
        val instance = ensureInstance("setPage") ?: return
        Log.d(TAG, "setPage()")
        val page = try {
            parsePage(pageJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse page JSON", e)
            return
        }
        instance.setPage(page)
    }

    @ReactMethod
    fun resetPage() {
        Log.d(TAG, "resetPage()")
        faroInstance?.resetPage()
    }

    @ReactMethod
    fun pause() {
        Log.d(TAG, "pause()")
        faroInstance?.pause()
    }

    @ReactMethod
    fun unpause() {
        Log.d(TAG, "unpause()")
        faroInstance?.unpause()
    }

    @ReactMethod
    fun getDeviceInfo(promise: Promise) {
        try {
            val context = reactApplicationContext
            val displayMetrics = context.resources.displayMetrics
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)

            val deviceInfo = buildJsonObject {
                put("platform", "android")
                put("osName", "Android")
                put("osVersion", Build.VERSION.RELEASE)
                put("deviceModel", Build.MODEL)
                put("deviceManufacturer", Build.MANUFACTURER)
                put("screenWidth", displayMetrics.widthPixels)
                put("screenHeight", displayMetrics.heightPixels)
                put("screenDensity", displayMetrics.density)
                put("isEmulator", isEmulator())
                put("appVersion", packageInfo.versionName ?: "")
                put("appBuildNumber", if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    packageInfo.longVersionCode.toString()
                } else {
                    @Suppress("DEPRECATION")
                    packageInfo.versionCode.toString()
                })
            }

            promise.resolve(deviceInfo.toString())
        } catch (e: Exception) {
            promise.reject("DEVICE_INFO_ERROR", e.message, e)
        }
    }

    // ---- Parsing helpers ----

    private fun parseConfig(configJson: String): FaroConfig {
        val obj = json.parseToJsonElement(configJson).jsonObject
        val transportHeaders = obj["transportHeaders"]?.jsonObject?.let { headers ->
            headers.entries.associate { it.key to it.value.jsonPrimitive.content }
        } ?: emptyMap()

        return FaroConfig(
            collectorUrl = obj["collectorUrl"]?.jsonPrimitive?.content ?: "",
            apiKey = obj["apiKey"]?.jsonPrimitive?.contentOrNull,
            app = parseApp(obj["app"]?.jsonObject),
            user = obj["user"]?.jsonObject?.let { parseUserObj(it) },
            sessionTracking = obj["sessionTracking"]?.jsonObject?.let { parseSessionConfig(it) }
                ?: SessionConfig(),
            enableCrashReporting = obj["enableCrashReporting"]?.jsonPrimitive?.boolean ?: false,
            enableAnrDetection = obj["enableAnrDetection"]?.jsonPrimitive?.boolean ?: true,
            enableLifecycleTracking = obj["enableLifecycleTracking"]?.jsonPrimitive?.boolean ?: true,
            enableNetworkMonitoring = obj["enableNetworkMonitoring"]?.jsonPrimitive?.boolean ?: true,
            batchConfig = obj["batchConfig"]?.jsonObject?.let { parseBatchConfig(it) }
                ?: BatchConfig(),
            internalLoggerLevel = parseLoggerLevel(
                obj["internalLoggerLevel"]?.jsonPrimitive?.contentOrNull
            ),
            eventDomain = obj["eventDomain"]?.jsonPrimitive?.contentOrNull ?: "app",
            transportHeaders = transportHeaders
        )
    }

    private fun parseSessionConfig(obj: JsonObject): SessionConfig {
        return SessionConfig(
            enabled = obj["enabled"]?.jsonPrimitive?.boolean ?: true,
            persistent = obj["persistent"]?.jsonPrimitive?.boolean ?: true,
            maxSessionDurationMs = obj["maxSessionDurationMs"]?.jsonPrimitive?.long
                ?: (4 * 60 * 60 * 1000L),
            sessionTimeoutMs = obj["sessionTimeoutMs"]?.jsonPrimitive?.long
                ?: (15 * 60 * 1000L),
            samplingRate = obj["samplingRate"]?.jsonPrimitive?.double ?: 1.0
        )
    }

    private fun parseBatchConfig(obj: JsonObject): BatchConfig {
        return BatchConfig(
            itemLimit = obj["itemLimit"]?.jsonPrimitive?.int ?: 30,
            sendTimeoutMs = obj["sendTimeoutMs"]?.jsonPrimitive?.long ?: 5000L
        )
    }

    private fun parseLoggerLevel(level: String?): InternalLoggerLevel {
        return when (level?.lowercase()) {
            "verbose" -> InternalLoggerLevel.VERBOSE
            "debug" -> InternalLoggerLevel.DEBUG
            "info" -> InternalLoggerLevel.INFO
            "warn" -> InternalLoggerLevel.WARN
            "error" -> InternalLoggerLevel.ERROR
            "none" -> InternalLoggerLevel.NONE
            else -> InternalLoggerLevel.ERROR
        }
    }

    private fun parseUserObj(obj: JsonObject): MetaUser {
        return MetaUser(
            email = obj["email"]?.jsonPrimitive?.contentOrNull,
            id = obj["id"]?.jsonPrimitive?.contentOrNull,
            username = obj["username"]?.jsonPrimitive?.contentOrNull,
            fullName = obj["fullName"]?.jsonPrimitive?.contentOrNull,
            roles = obj["roles"]?.jsonPrimitive?.contentOrNull,
            hash = obj["hash"]?.jsonPrimitive?.contentOrNull,
            attributes = obj["attributes"]?.jsonObject?.let { attrs ->
                attrs.entries.associate { it.key to it.value.jsonPrimitive.content }
            }
        )
    }

    private fun parseApp(obj: JsonObject?): MetaApp {
        if (obj == null) return MetaApp()
        return MetaApp(
            name = obj["name"]?.jsonPrimitive?.contentOrNull,
            version = obj["version"]?.jsonPrimitive?.contentOrNull,
            environment = obj["environment"]?.jsonPrimitive?.contentOrNull,
            namespace = obj["namespace"]?.jsonPrimitive?.contentOrNull,
            release = obj["release"]?.jsonPrimitive?.contentOrNull,
            bundleId = obj["bundleId"]?.jsonPrimitive?.contentOrNull
        )
    }

    private fun parseUser(userJson: String): MetaUser {
        val obj = json.parseToJsonElement(userJson).jsonObject
        return MetaUser(
            email = obj["email"]?.jsonPrimitive?.contentOrNull,
            id = obj["id"]?.jsonPrimitive?.contentOrNull,
            username = obj["username"]?.jsonPrimitive?.contentOrNull,
            fullName = obj["fullName"]?.jsonPrimitive?.contentOrNull,
            roles = obj["roles"]?.jsonPrimitive?.contentOrNull,
            hash = obj["hash"]?.jsonPrimitive?.contentOrNull,
            attributes = obj["attributes"]?.jsonObject?.let { attrs ->
                attrs.entries.associate { it.key to it.value.jsonPrimitive.content }
            }
        )
    }

    private fun parsePage(pageJson: String): MetaPage {
        val obj = json.parseToJsonElement(pageJson).jsonObject
        return MetaPage(
            id = obj["id"]?.jsonPrimitive?.contentOrNull,
            url = obj["url"]?.jsonPrimitive?.contentOrNull,
            attributes = obj["attributes"]?.jsonObject?.let { attrs ->
                attrs.entries.associate { it.key to it.value.jsonPrimitive.content }
            }
        )
    }

    private fun parseStringMap(jsonStr: String): Map<String, String> {
        return try {
            val obj = json.parseToJsonElement(jsonStr).jsonObject
            obj.entries.associate { it.key to it.value.jsonPrimitive.content }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun parseDoubleMap(jsonStr: String): Map<String, Double> {
        return try {
            val obj = json.parseToJsonElement(jsonStr).jsonObject
            obj.entries.associate { it.key to it.value.jsonPrimitive.double }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    private fun parseStacktrace(jsonStr: String): Stacktrace {
        return try {
            val obj = json.parseToJsonElement(jsonStr).jsonObject
            val frames = obj["frames"]?.jsonArray?.map { frameEl ->
                val frame = frameEl.jsonObject
                ExceptionStackFrame(
                    filename = frame["filename"]?.jsonPrimitive?.content ?: "unknown",
                    function = frame["function"]?.jsonPrimitive?.content ?: "anonymous",
                    lineno = frame["lineno"]?.jsonPrimitive?.intOrNull,
                    colno = frame["colno"]?.jsonPrimitive?.intOrNull
                )
            } ?: emptyList()
            Stacktrace(frames = frames)
        } catch (_: Exception) {
            Stacktrace(frames = emptyList())
        }
    }

    private fun isEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.PRODUCT.contains("sdk_gphone"))
    }
}
