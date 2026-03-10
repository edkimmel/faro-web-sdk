package com.edkimmel.faro.transport

class TransportException(message: String, cause: Throwable? = null) : Exception(message, cause)

interface Transport {
    val name: String
    fun send(body: TransportBody)
    fun shutdown()
}
