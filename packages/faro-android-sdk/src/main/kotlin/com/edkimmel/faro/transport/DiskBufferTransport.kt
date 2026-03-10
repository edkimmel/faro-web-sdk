package com.edkimmel.faro.transport

import android.content.Context
import com.edkimmel.faro.internal.InternalLogger
import com.edkimmel.faro.persistence.DiskBuffer
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Transport wrapper that writes signals to disk first, then sends via HTTP.
 * Ensures data persistence across app kills and crashes.
 */
internal class DiskBufferTransport(
    private val diskBuffer: DiskBuffer,
    private val httpTransport: HttpTransport,
    private val logger: InternalLogger,
    private val retryIntervalMs: Long = 30_000L,
    private val appContext: Context? = null
) : Transport {
    override val name = "faro-android:transport-disk-buffer"

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var retryJob: Job? = null
    private val sendMutex = Mutex()

    fun start() {
        // Send any pending crashes and signals off the calling thread
        scope.launch {
            sendPendingCrashes()
            sendPendingSignals()
        }
        // Schedule periodic retry for failed sends
        startRetryLoop()
    }

    override fun send(body: TransportBody) {
        // Write to disk first
        try {
            diskBuffer.writeSignal(body)
        } catch (e: Exception) {
            logger.error("Failed to write signal to disk, signal may be lost", e)
        }

        // Then try to send immediately
        scope.launch {
            sendPendingSignals()
        }
    }

    fun sendCrash(body: TransportBody) {
        // Write crash data synchronously to disk
        diskBuffer.writeCrash(body)
    }

    private suspend fun sendPendingCrashes() {
        sendMutex.withLock {
            val crashes = diskBuffer.readPendingCrashes()
            for (crash in crashes) {
                if (!isSystemReady()) {
                    logger.debug("Upload blocked by system conditions, will retry later")
                    break
                }
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

    private suspend fun sendPendingSignals() {
        sendMutex.withLock {
            val signals = diskBuffer.readPendingSignals()
            for (signal in signals) {
                if (!isSystemReady()) {
                    logger.debug("Upload blocked by system conditions, will retry later")
                    break
                }
                try {
                    httpTransport.send(signal.body)
                    diskBuffer.deleteFile(signal)
                } catch (e: Exception) {
                    logger.debug("Failed to send signal, will retry later")
                    break
                }
            }
        }
    }

    private fun isSystemReady(): Boolean {
        val ctx = appContext ?: return true
        val blockers = UploadConditions.currentBlockers(ctx)
        if (blockers.isNotEmpty()) {
            logger.debug("Upload blockers: ${blockers.joinToString { it.reason }}")
            return false
        }
        return true
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
