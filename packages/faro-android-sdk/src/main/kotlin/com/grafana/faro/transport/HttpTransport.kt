package com.grafana.faro.transport

import com.grafana.faro.internal.InternalLogger
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

internal class HttpTransport(
    private val collectorUrl: String,
    private val apiKey: String?,
    private val logger: InternalLogger,
    private val onRateLimited: ((retryAfterMs: Long) -> Unit)? = null
) : Transport {
    override val name = "faro-android:transport-http"

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    private val jsonMediaType = "application/json".toMediaType()

    companion object {
        private const val TOO_MANY_REQUESTS = 429
        private const val ACCEPTED = 202
        private const val DEFAULT_RATE_LIMIT_BACKOFF_MS = 5000L
    }

    @Volatile
    private var disabledUntilMs: Long = 0

    override fun send(body: TransportBody) {
        val now = System.currentTimeMillis()
        if (now < disabledUntilMs) {
            logger.warn("Transport rate limited, dropping payload until $disabledUntilMs")
            return
        }

        val jsonBody = TransportBody.toJson(body)

        val requestBuilder = Request.Builder()
            .url(collectorUrl)
            .post(jsonBody.toRequestBody(jsonMediaType))
            .header("Content-Type", "application/json")

        apiKey?.let {
            requestBuilder.header("x-api-key", it)
        }

        body.meta.session?.id?.let { sessionId ->
            requestBuilder.header("x-faro-session-id", sessionId)
        }

        try {
            val response = client.newCall(requestBuilder.build()).execute()
            response.use {
                when (response.code) {
                    ACCEPTED -> {
                        logger.debug("Payload sent successfully")
                    }
                    TOO_MANY_REQUESTS -> {
                        val retryAfterMs = parseRetryAfter(response.header("Retry-After"))
                        disabledUntilMs = System.currentTimeMillis() + retryAfterMs
                        logger.warn("Rate limited, backing off for ${retryAfterMs}ms")
                        onRateLimited?.invoke(retryAfterMs)
                    }
                    else -> {
                        logger.error("Unexpected response code: ${response.code}")
                    }
                }
            }
        } catch (e: Exception) {
            logger.error("Failed to send payload", e)
            throw TransportException("Failed to send payload to $collectorUrl", e)
        }
    }

    override fun shutdown() {
        client.dispatcher.executorService.shutdown()
        client.connectionPool.evictAll()
    }

    private fun parseRetryAfter(header: String?): Long {
        if (header == null) return DEFAULT_RATE_LIMIT_BACKOFF_MS

        // Try parsing as seconds
        header.toLongOrNull()?.let { return it * 1000 }

        // Try parsing as HTTP date
        try {
            val date = java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", java.util.Locale.US)
                .parse(header)
            if (date != null) {
                return maxOf(0, date.time - System.currentTimeMillis())
            }
        } catch (_: Exception) {}

        return DEFAULT_RATE_LIMIT_BACKOFF_MS
    }
}
