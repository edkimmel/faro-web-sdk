package com.grafana.faro.instrumentations.anr

import android.os.Handler
import android.os.Looper
import com.grafana.faro.FaroInstance
import com.grafana.faro.api.models.ExceptionStackFrame
import com.grafana.faro.api.models.Stacktrace
import com.grafana.faro.instrumentations.Instrumentation
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Detects Application Not Responding (ANR) conditions by monitoring
 * main thread responsiveness with a watchdog thread.
 */
class AnrInstrumentation(
    private val timeoutMs: Long = 5000L,
    private val checkIntervalMs: Long = 5000L
) : Instrumentation {
    override val name = "faro-android:instrumentation-anr"

    private var faro: FaroInstance? = null
    private var watchdogThread: Thread? = null

    @Volatile
    private var isRunning = false

    override fun install(faro: FaroInstance) {
        this.faro = faro
        isRunning = true

        watchdogThread = Thread({
            val mainHandler = Handler(Looper.getMainLooper())
            val mainThread = Looper.getMainLooper().thread

            while (isRunning) {
                val responded = AtomicBoolean(false)

                mainHandler.post { responded.set(true) }

                try {
                    Thread.sleep(timeoutMs)
                } catch (_: InterruptedException) {
                    break
                }

                if (!responded.get() && isRunning) {
                    reportAnr(mainThread)
                    // Wait before checking again to avoid spam
                    try {
                        Thread.sleep(checkIntervalMs)
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            }
        }, "faro-anr-watchdog").apply {
            isDaemon = true
            start()
        }
    }

    private fun reportAnr(mainThread: Thread) {
        val stackTrace = mainThread.stackTrace
        val frames = stackTrace.map { element ->
            ExceptionStackFrame(
                filename = element.fileName ?: "unknown",
                function = "${element.className}.${element.methodName}",
                lineno = element.lineNumber.takeIf { it > 0 },
                colno = null
            )
        }

        faro?.pushError(
            type = "ANR",
            value = "Application Not Responding - main thread blocked for ${timeoutMs}ms",
            stacktrace = Stacktrace(frames),
            context = mapOf(
                "source" to "anr_detection",
                "timeout_ms" to timeoutMs.toString()
            )
        )
    }

    override fun uninstall() {
        isRunning = false
        watchdogThread?.interrupt()
        watchdogThread = null
        faro = null
    }
}
