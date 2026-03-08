package com.grafana.faro.transport

import com.grafana.faro.internal.InternalLogger
import kotlinx.coroutines.*
import java.util.concurrent.CopyOnWriteArrayList

data class BatchConfig(
    val itemLimit: Int = 30,
    val sendTimeoutMs: Long = 5000L
)

internal class BatchExecutor(
    private val config: BatchConfig,
    private val logger: InternalLogger,
    private val onFlush: (List<TransportItem>) -> Unit
) {
    private val buffer = CopyOnWriteArrayList<TransportItem>()
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var flushJob: Job? = null

    @Volatile
    var isPaused: Boolean = false

    fun add(item: TransportItem) {
        if (isPaused) {
            logger.debug("BatchExecutor is paused, dropping item")
            return
        }

        buffer.add(item)

        if (buffer.size >= config.itemLimit) {
            flush()
        } else {
            scheduleFlush()
        }
    }

    @Synchronized
    private fun scheduleFlush() {
        flushJob?.cancel()
        if (config.sendTimeoutMs > 0) {
            flushJob = scope.launch {
                delay(config.sendTimeoutMs)
                flush()
            }
        }
    }

    @Synchronized
    fun flush() {
        if (buffer.isEmpty()) return

        val items = ArrayList(buffer)
        buffer.clear()
        flushJob?.cancel()

        scope.launch {
            try {
                onFlush(items)
            } catch (e: Exception) {
                logger.error("Error flushing batch", e)
            }
        }
    }

    fun shutdown() {
        flush()
        scope.cancel()
    }
}
