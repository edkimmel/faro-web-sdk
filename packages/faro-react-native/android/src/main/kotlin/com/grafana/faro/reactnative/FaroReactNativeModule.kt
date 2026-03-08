package com.grafana.faro.reactnative

import android.os.Build
import android.util.DisplayMetrics
import com.facebook.react.bridge.*
import com.grafana.faro.Faro
import com.grafana.faro.FaroConfig
import com.grafana.faro.FaroInstance
import com.grafana.faro.api.models.*
import kotlinx.serialization.json.*

class FaroReactNativeModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = "FaroReactNative"

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = false
        explicitNulls = false
    }

    private var faroInstance: FaroInstance? = null

    @ReactMethod
    fun initialize(configJson: String, promise: Promise) {
        try {
            val config = parseConfig(configJson)
            val app = reactApplicationContext.applicationContext as android.app.Application
            faroInstance = Faro.initialize(app, config)
            promise.resolve(null)
        } catch (e: Exception) {
            // If already initialized, just get the existing instance
            if (Faro.isInitialized()) {
                faroInstance = Faro.getInstance()
                promise.resolve(null)
            } else {
                promise.reject("FARO_INIT_ERROR", e.message, e)
            }
        }
    }

    @ReactMethod
    fun pushLog(level: String, message: String, context: String?, timestamp: String?) {
        val instance = faroInstance ?: return
        val ctx = context?.let { parseStringMap(it) }
        instance.pushLog(
            message = message,
            level = LogLevel.fromString(level),
            context = ctx
        )
    }

    @ReactMethod
    fun pushError(type: String, value: String, stacktrace: String?, context: String?) {
        val instance = faroInstance ?: return
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
        val instance = faroInstance ?: return
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
        val instance = faroInstance ?: return
        val attrs = attributes?.let { parseStringMap(it) }
        instance.pushEvent(
            name = name,
            attributes = attrs,
            domain = domain
        )
    }

    @ReactMethod
    fun setUser(userJson: String) {
        val instance = faroInstance ?: return
        val user = parseUser(userJson)
        instance.setUser(user)
    }

    @ReactMethod
    fun resetUser() {
        faroInstance?.resetUser()
    }

    @ReactMethod
    fun setSession(sessionId: String) {
        faroInstance?.setSession(sessionId)
    }

    @ReactMethod
    fun setView(viewName: String) {
        faroInstance?.setView(viewName)
    }

    @ReactMethod
    fun pause() {
        faroInstance?.pause()
    }

    @ReactMethod
    fun unpause() {
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
        return FaroConfig(
            collectorUrl = obj["collectorUrl"]?.jsonPrimitive?.content ?: "",
            apiKey = obj["apiKey"]?.jsonPrimitive?.contentOrNull,
            app = parseApp(obj["app"]?.jsonObject),
            enableCrashReporting = obj["enableCrashReporting"]?.jsonPrimitive?.boolean ?: false,
            enableAnrDetection = obj["enableAnrDetection"]?.jsonPrimitive?.boolean ?: true,
            enableLifecycleTracking = obj["enableLifecycleTracking"]?.jsonPrimitive?.boolean ?: true,
            enableNetworkMonitoring = obj["enableNetworkMonitoring"]?.jsonPrimitive?.boolean ?: true,
            eventDomain = obj["eventDomain"]?.jsonPrimitive?.contentOrNull ?: "app"
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
