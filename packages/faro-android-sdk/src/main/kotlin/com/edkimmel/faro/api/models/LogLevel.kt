package com.edkimmel.faro.api.models

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class LogLevel(val value: String) {
    @SerialName("trace") TRACE("trace"),
    @SerialName("debug") DEBUG("debug"),
    @SerialName("info") INFO("info"),
    @SerialName("log") LOG("log"),
    @SerialName("warn") WARN("warn"),
    @SerialName("error") ERROR("error");

    companion object {
        fun fromString(value: String): LogLevel {
            return entries.firstOrNull { it.value == value.lowercase() } ?: LOG
        }
    }
}
