package com.edkimmel.faro.persistence

import com.edkimmel.faro.transport.TransportBody
import java.io.File

data class SignalFile(
    val file: File,
    val body: TransportBody
)
