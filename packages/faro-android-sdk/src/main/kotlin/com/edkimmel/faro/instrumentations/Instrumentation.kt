package com.edkimmel.faro.instrumentations

import com.edkimmel.faro.FaroInstance

interface Instrumentation {
    val name: String
    fun install(faro: FaroInstance)
    fun uninstall()
}
