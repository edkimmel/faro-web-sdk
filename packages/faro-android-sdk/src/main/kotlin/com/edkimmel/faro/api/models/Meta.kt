package com.edkimmel.faro.api.models

import kotlinx.serialization.Serializable

@Serializable
data class Meta(
    val sdk: MetaSDK? = null,
    val app: MetaApp? = null,
    val user: MetaUser? = null,
    val session: MetaSession? = null,
    val page: MetaPage? = null,
    val browser: MetaBrowser? = null,
    val view: MetaView? = null,
    val device: MetaDevice? = null
)

@Serializable
data class MetaSDK(
    val name: String? = null,
    val version: String? = null,
    val integrations: List<MetaSDKIntegration>? = null
)

@Serializable
data class MetaSDKIntegration(
    val name: String? = null,
    val version: String? = null
)

@Serializable
data class MetaApp(
    val name: String? = null,
    val namespace: String? = null,
    val release: String? = null,
    val version: String? = null,
    val environment: String? = null,
    val bundleId: String? = null
)

@Serializable
data class MetaUser(
    val email: String? = null,
    val id: String? = null,
    val username: String? = null,
    val fullName: String? = null,
    val roles: String? = null,
    val hash: String? = null,
    val attributes: Map<String, String>? = null
)

@Serializable
data class MetaSession(
    val id: String? = null,
    val attributes: Map<String, String>? = null
)

@Serializable
data class MetaPage(
    val id: String? = null,
    val url: String? = null,
    val attributes: Map<String, String>? = null
)

@Serializable
data class MetaBrowser(
    val name: String? = null,
    val version: String? = null,
    val os: String? = null,
    val mobile: Boolean? = null,
    val userAgent: String? = null,
    val language: String? = null,
    val viewportWidth: String? = null,
    val viewportHeight: String? = null
)

@Serializable
data class MetaView(
    val name: String? = null
)

@Serializable
data class MetaDevice(
    val platform: String? = null,
    val osName: String? = null,
    val osVersion: String? = null,
    val deviceModel: String? = null,
    val deviceManufacturer: String? = null,
    val screenWidth: Int? = null,
    val screenHeight: Int? = null,
    val screenDensity: Float? = null,
    val isEmulator: Boolean? = null,
    val appVersion: String? = null,
    val appBuildNumber: String? = null
)
