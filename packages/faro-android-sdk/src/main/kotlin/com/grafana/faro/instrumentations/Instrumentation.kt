package com.grafana.faro.instrumentations

import com.grafana.faro.FaroInstance

interface Instrumentation {
    val name: String
    fun install(faro: FaroInstance)
    fun uninstall()
}
