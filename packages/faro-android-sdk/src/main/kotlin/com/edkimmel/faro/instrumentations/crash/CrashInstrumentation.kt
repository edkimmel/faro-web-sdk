package com.edkimmel.faro.instrumentations.crash

import com.edkimmel.faro.FaroInstance
import com.edkimmel.faro.api.models.ExceptionEvent
import com.edkimmel.faro.api.models.ExceptionStackFrame
import com.edkimmel.faro.api.models.Stacktrace
import com.edkimmel.faro.instrumentations.Instrumentation
import com.edkimmel.faro.internal.Clock

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
            try {
                handleCrash(thread, throwable)
            } catch (_: Throwable) {
                // Best effort — never prevent the previous handler from running
            } finally {
                // Always forward to previous handler (Crashlytics, etc.)
                previousHandler?.uncaughtException(thread, throwable)
            }
        }
    }

    private fun handleCrash(thread: Thread, throwable: Throwable) {
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
    }

    private fun parseStacktrace(throwable: Throwable): Stacktrace {
        val allFrames = mutableListOf<ExceptionStackFrame>()

        // Add top-level exception frames
        allFrames.addAll(throwable.stackTrace.map { element ->
            ExceptionStackFrame(
                filename = element.fileName ?: "unknown",
                function = "${element.className}.${element.methodName}",
                lineno = element.lineNumber.takeIf { it > 0 },
                colno = null
            )
        })

        // Walk full cause chain (cap at 10 to prevent infinite loops from circular causes)
        var cause = throwable.cause
        var depth = 0
        while (cause != null && depth < 10) {
            allFrames.addAll(cause.stackTrace.map { element ->
                ExceptionStackFrame(
                    filename = element.fileName ?: "unknown",
                    function = "Caused by ${cause!!.javaClass.name}: ${element.className}.${element.methodName}",
                    lineno = element.lineNumber.takeIf { it > 0 },
                    colno = null
                )
            })
            cause = cause.cause
            depth++
        }

        return Stacktrace(frames = allFrames)
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
