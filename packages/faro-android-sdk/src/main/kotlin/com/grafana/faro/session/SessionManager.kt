package com.grafana.faro.session

import com.grafana.faro.internal.InternalLogger
import java.util.UUID

data class SessionConfig(
    val enabled: Boolean = true,
    val persistent: Boolean = true,
    val maxSessionDurationMs: Long = 4 * 60 * 60 * 1000, // 4 hours
    val sessionTimeoutMs: Long = 15 * 60 * 1000,          // 15 minutes inactivity
    val samplingRate: Double = 1.0
)

internal class SessionManager(
    private val config: SessionConfig,
    private val store: SessionStore,
    private val logger: InternalLogger
) {
    private var currentSessionId: String? = null
    private var sessionStartTime: Long = 0
    private var lastActivityTime: Long = 0
    private var isSampled: Boolean = true

    fun start(): String {
        if (!config.enabled) {
            logger.debug("Session tracking disabled")
            return ""
        }

        // Check for persisted session
        if (config.persistent) {
            val stored = store.loadSession()
            if (stored != null && !isExpired(stored)) {
                currentSessionId = stored.sessionId
                sessionStartTime = stored.startTime
                lastActivityTime = System.currentTimeMillis()
                isSampled = stored.isSampled
                logger.debug("Restored session: $currentSessionId")
                return currentSessionId!!
            }
        }

        return createNewSession()
    }

    fun getSessionId(): String {
        if (currentSessionId == null) {
            return start()
        }

        // Check if session needs rotation
        val now = System.currentTimeMillis()
        if (now - sessionStartTime > config.maxSessionDurationMs ||
            now - lastActivityTime > config.sessionTimeoutMs
        ) {
            return createNewSession()
        }

        lastActivityTime = now
        if (config.persistent) {
            store.saveSession(StoredSession(currentSessionId!!, sessionStartTime, isSampled))
        }

        return currentSessionId!!
    }

    fun isSampled(): Boolean = isSampled

    fun setSessionId(sessionId: String) {
        currentSessionId = sessionId
        sessionStartTime = System.currentTimeMillis()
        lastActivityTime = sessionStartTime
        isSampled = true
        if (config.persistent) {
            store.saveSession(StoredSession(sessionId, sessionStartTime, isSampled))
        }
    }

    private fun createNewSession(): String {
        currentSessionId = generateSessionId()
        sessionStartTime = System.currentTimeMillis()
        lastActivityTime = sessionStartTime
        isSampled = Math.random() < config.samplingRate

        if (config.persistent) {
            store.saveSession(StoredSession(currentSessionId!!, sessionStartTime, isSampled))
        }

        logger.debug("Created new session: $currentSessionId (sampled: $isSampled)")
        return currentSessionId!!
    }

    private fun isExpired(stored: StoredSession): Boolean {
        val now = System.currentTimeMillis()
        return now - stored.startTime > config.maxSessionDurationMs
    }

    private fun generateSessionId(): String {
        return UUID.randomUUID().toString().replace("-", "").take(16)
    }
}
