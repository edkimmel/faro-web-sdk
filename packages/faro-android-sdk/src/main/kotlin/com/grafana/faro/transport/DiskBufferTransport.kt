package com.grafana.faro.transport

import com.grafana.faro.internal.InternalLogger
import com.grafana.faro.persistence.DiskBuffer
import kotlinx.coroutines.*

/**
 * Transport wrapper that writes signals to disk first, then sends via HTTP.
 * Ensures data persistence across app kills and crashes.
 */
internal class DiskBufferTransport(
    private val diskBuffer: DiskBuffer,
    private val httpTransport: HttpTransport,
    private val logger: InternalLogger,
    private val retryIntervalMs: Long = 30_000L
) : Transport {
    override val name = "faro-android:transport-disk-buffer"

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var retryJob: Job? = null

    fun start() {
        // Send any pending crashes from previous session first
        sendPendingCrashes()
        // Then send any pending signals
        sendPendingSignals()
        // Schedule periodic retry for failed sends
        startRetryLoop()
    }

    override fun send(body: TransportBody) {
        // Write to disk first
        diskBuffer.writeSignal(body)

        // Then try to send immediately
        scope.launch {
            sendPendingSignals()
        }
    }

    fun sendCrash(body: TransportBody) {
        // Write crash data synchronously to disk
        diskBuffer.writeCrash(body)
    }

    private fun sendPendingCrashes() {
        scope.launch {
            val crashes = diskBuffer.readPendingCrashes()
            for (crash in crashes) {
                try {
                    httpTransport.send(crash.body)
                    diskBuffer.deleteFile(crash)
                    logger.info("Sent pending crash report: ${crash.file.name}")
                } catch (e: Exception) {
                    logger.error("Failed to send crash report, will retry", e)
                    break // Stop trying if one fails
                }
            }
        }
    }

    private fun sendPendingSignals() {
        val signals = diskBuffer.readPendingSignals()
        for (signal in signals) {
            try {
                httpTransport.send(signal.body)
                diskBuffer.deleteFile(signal)
            } catch (e: Exception) {
                logger.debug("Failed to send signal, will retry later")
                break
            }
        }
    }

    private fun startRetryLoop() {
        retryJob?.cancel()
        retryJob = scope.launch {
            while (isActive) {
                delay(retryIntervalMs)
                sendPendingSignals()
            }
        }
    }

    override fun shutdown() {
        retryJob?.cancel()
        scope.cancel()
        httpTransport.shutdown()
    }
}
