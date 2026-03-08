package com.grafana.faro.instrumentations.crash

import com.grafana.faro.FaroInstance
import com.grafana.faro.api.models.ExceptionEvent
import com.grafana.faro.api.models.ExceptionStackFrame
import com.grafana.faro.api.models.Stacktrace
import com.grafana.faro.instrumentations.Instrumentation
import com.grafana.faro.internal.Clock

/**
 * Captures uncaught exceptions and writes crash data to disk.
 * Designed to coexist with other crash reporters (e.g., Crashlytics)
 * by chaining to the previous UncaughtExceptionHandler.
 */
class CrashInstrumentation : Instrumentation {
    override val name = "faro-android:instrumentation-crash"

    private var faro: FaroInstance? = null
    private var previousHandler: Thread.UncaughtExceptionHandler? = null

    override fun install(faro: FaroInstance) {
        this.faro = faro

        // Chain with existing handler (e.g., Crashlytics)
        previousHandler = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            handleCrash(thread, throwable)

            // Forward to previous handler (Crashlytics, etc.)
            previousHandler?.uncaughtException(thread, throwable)
        }
    }

    private fun handleCrash(thread: Thread, throwable: Throwable) {
        try {
            val exception = ExceptionEvent(
                type = throwable.javaClass.name,
                value = throwable.message ?: "Unknown error",
                timestamp = Clock.nowTimestamp(),
                stacktrace = parseStacktrace(throwable),
                context = mapOf(
                    "thread" to thread.name,
                    "isFatal" to "true",
                    "source" to "native_crash"
                )
            )

            // Write crash to disk synchronously - this must complete before process dies
            faro?.writeCrashToDisk(exception)
        } catch (_: Exception) {
            // Best effort in crash handler - don't throw
        }
    }

    private fun parseStacktrace(throwable: Throwable): Stacktrace {
        val frames = throwable.stackTrace.map { element ->
            ExceptionStackFrame(
                filename = element.fileName ?: "unknown",
                function = "${element.className}.${element.methodName}",
                lineno = element.lineNumber.takeIf { it > 0 },
                colno = null
            )
        }

        // Include cause chain
        val causeFrames = throwable.cause?.let { cause ->
            cause.stackTrace.map { element ->
                ExceptionStackFrame(
                    filename = element.fileName ?: "unknown",
                    function = "Caused by ${cause.javaClass.name}: ${element.className}.${element.methodName}",
                    lineno = element.lineNumber.takeIf { it > 0 },
                    colno = null
                )
            }
        } ?: emptyList()

        return Stacktrace(frames = frames + causeFrames)
    }

    override fun uninstall() {
        // Restore previous handler
        previousHandler?.let {
            Thread.setDefaultUncaughtExceptionHandler(it)
        }
        previousHandler = null
        faro = null
    }
}
