package com.edkimmel.faro

import com.edkimmel.faro.api.models.MetaApp
import com.edkimmel.faro.api.models.MetaUser
import com.edkimmel.faro.internal.InternalLoggerLevel
import com.edkimmel.faro.persistence.DiskBufferConfig
import com.edkimmel.faro.persistence.PreInitBufferConfig
import com.edkimmel.faro.session.SessionConfig
import com.edkimmel.faro.transport.BatchConfig
import com.edkimmel.faro.transport.TransportItem

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
    val eventDomain: String = "app",
    /** Configuration for the pre-initialization buffer.
     * The pre-init buffer captures signals sent before initialize() and replays them
     * when the SDK starts. When null, defaults are used. */
    val preInitBufferConfig: PreInitBufferConfig? = null
)
