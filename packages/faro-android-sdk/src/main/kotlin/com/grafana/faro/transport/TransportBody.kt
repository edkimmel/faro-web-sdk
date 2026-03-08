package com.grafana.faro.transport

import com.grafana.faro.api.models.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class TransportBody(
    val meta: Meta,
    val logs: List<LogEvent>? = null,
    val exceptions: List<ExceptionEvent>? = null,
    val measurements: List<MeasurementEvent>? = null,
    val events: List<EventEvent>? = null
) {
    companion object {
        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = false
            explicitNulls = false
        }

        fun toJson(body: TransportBody): String = json.encodeToString(body)

        fun fromJson(jsonString: String): TransportBody = json.decodeFromString(jsonString)
    }
}

enum class TransportItemType(val value: String) {
    LOG("log"),
    EXCEPTION("exception"),
    MEASUREMENT("measurement"),
    EVENT("event");
}

data class TransportItem(
    val type: TransportItemType,
    val payload: Any,
    val meta: Meta
)
