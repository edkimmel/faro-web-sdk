package com.grafana.faro.internal

import android.util.Log

enum class InternalLoggerLevel {
    VERBOSE, DEBUG, INFO, WARN, ERROR, NONE
}

internal class InternalLogger(
    private val level: InternalLoggerLevel = InternalLoggerLevel.ERROR
) {
    companion object {
        private const val TAG = "Faro"
    }

    fun verbose(message: String) {
        if (level <= InternalLoggerLevel.VERBOSE) Log.v(TAG, message)
    }

    fun debug(message: String) {
        if (level <= InternalLoggerLevel.DEBUG) Log.d(TAG, message)
    }

    fun info(message: String) {
        if (level <= InternalLoggerLevel.INFO) Log.i(TAG, message)
    }

    fun warn(message: String) {
        if (level <= InternalLoggerLevel.WARN) Log.w(TAG, message)
    }

    fun error(message: String, throwable: Throwable? = null) {
        if (level <= InternalLoggerLevel.ERROR) Log.e(TAG, message, throwable)
    }
}
