package com.grafana.faro.transport

interface Transport {
    val name: String
    fun send(body: TransportBody)
    fun shutdown()
}
