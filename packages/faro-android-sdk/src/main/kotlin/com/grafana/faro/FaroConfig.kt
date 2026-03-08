package com.grafana.faro

import com.grafana.faro.api.models.MetaApp
import com.grafana.faro.api.models.MetaUser
import com.grafana.faro.internal.InternalLoggerLevel
import com.grafana.faro.persistence.DiskBufferConfig
import com.grafana.faro.session.SessionConfig
import com.grafana.faro.transport.BatchConfig
import com.grafana.faro.transport.TransportItem

data class FaroConfig(
    val collectorUrl: String,
    val app: MetaApp,
    val apiKey: String? = null,
    val user: MetaUser? = null,
    val sessionTracking: SessionConfig = SessionConfig(),
    val enableCrashReporting: Boolean = false,
    val enableAnrDetection: Boolean = true,
    val enableLifecycleTracking: Boolean = true,
    val enableNetworkMonitoring: Boolean = true,
    val batchConfig: BatchConfig = BatchConfig(),
    val diskBufferConfig: DiskBufferConfig = DiskBufferConfig(),
    val internalLoggerLevel: InternalLoggerLevel = InternalLoggerLevel.ERROR,
    val beforeSend: ((TransportItem) -> TransportItem?)? = null,
    val ignoreErrors: List<Regex> = emptyList(),
    val ignoreUrls: List<Regex> = emptyList(),
    val eventDomain: String = "app"
)
