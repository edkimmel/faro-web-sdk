package com.grafana.faro.persistence

import com.grafana.faro.transport.TransportBody
import java.io.File

data class SignalFile(
    val file: File,
    val body: TransportBody
)
