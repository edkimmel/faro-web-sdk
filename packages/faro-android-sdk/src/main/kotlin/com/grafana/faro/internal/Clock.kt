package com.grafana.faro.internal

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

internal object Clock {
    private val formatter = DateTimeFormatter.ISO_INSTANT

    fun nowTimestamp(): String {
        return formatter.format(Instant.now().atOffset(ZoneOffset.UTC))
    }

    fun nowMillis(): Long = System.currentTimeMillis()
}
