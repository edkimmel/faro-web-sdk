package com.grafana.faro.instrumentations.network

import com.grafana.faro.FaroInstance
import com.grafana.faro.instrumentations.Instrumentation
import okhttp3.Interceptor
import okhttp3.Response

/**
 * OkHttp interceptor that monitors HTTP requests and reports them as measurements.
 *
 * Usage:
 *   val interceptor = OkHttpInstrumentation()
 *   val client = OkHttpClient.Builder()
 *       .addInterceptor(interceptor.createInterceptor())
 *       .build()
 */
class OkHttpInstrumentation : Instrumentation {
    override val name = "faro-android:instrumentation-okhttp"

    private var faro: FaroInstance? = null

    override fun install(faro: FaroInstance) {
        this.faro = faro
    }

    /**
     * Creates an OkHttp Interceptor that reports request metrics.
     * Add this to your OkHttpClient.Builder.
     */
    fun createInterceptor(): Interceptor {
        return Interceptor { chain ->
            val request = chain.request()
            val url = request.url.toString()
            val method = request.method

            // Check if this URL should be ignored (e.g., collector URL)
            if (faro?.shouldIgnoreUrl(url) == true) {
                return@Interceptor chain.proceed(request)
            }

            val startTimeMs = System.currentTimeMillis()
            var response: Response? = null
            var error: Exception? = null

            try {
                response = chain.proceed(request)
                return@Interceptor response
            } catch (e: Exception) {
                error = e
                throw e
            } finally {
                val durationMs = System.currentTimeMillis() - startTimeMs
                reportRequest(url, method, response, error, durationMs)
            }
        }
    }

    private fun reportRequest(
        url: String,
        method: String,
        response: Response?,
        error: Exception?,
        durationMs: Long
    ) {
        val values = mutableMapOf<String, Double>(
            "duration_ms" to durationMs.toDouble()
        )

        response?.let {
            values["status_code"] = it.code.toDouble()
            it.body?.contentLength()?.takeIf { len -> len >= 0 }?.let { len ->
                values["response_size"] = len.toDouble()
            }
        }

        val context = mutableMapOf(
            "url" to url,
            "method" to method
        )

        error?.let {
            context["error"] = it.message ?: it.javaClass.simpleName
        }

        response?.let {
            context["status_code"] = it.code.toString()
        }

        faro?.pushMeasurement(
            type = "http_request",
            values = values,
            context = context
        )
    }

    override fun uninstall() {
        faro = null
    }
}
