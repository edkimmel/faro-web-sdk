package com.grafana.faro.api.models

import kotlinx.serialization.Serializable

@Serializable
data class LogEvent(
    val message: String,
    val level: LogLevel,
    val timestamp: String,
    val context: Map<String, String>? = null,
    val trace: TraceContext? = null
)

@Serializable
data class ExceptionStackFrame(
    val filename: String,
    val function: String,
    val colno: Int? = null,
    val lineno: Int? = null
)

@Serializable
data class Stacktrace(
    val frames: List<ExceptionStackFrame>
)

@Serializable
data class ExceptionEvent(
    val type: String,
    val value: String,
    val timestamp: String,
    val stacktrace: Stacktrace? = null,
    val context: Map<String, String>? = null,
    val trace: TraceContext? = null
)

@Serializable
data class MeasurementEvent(
    val type: String,
    val values: Map<String, Double>,
    val timestamp: String,
    val context: Map<String, String>? = null,
    val trace: TraceContext? = null
)

@Serializable
data class EventEvent(
    val name: String,
    val timestamp: String,
    val domain: String? = null,
    val attributes: Map<String, String>? = null,
    val trace: TraceContext? = null
)

@Serializable
data class TraceContext(
    val trace_id: String,
    val span_id: String
)
