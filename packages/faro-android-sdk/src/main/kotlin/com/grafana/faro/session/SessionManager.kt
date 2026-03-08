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
    private val lock = Object()
    private var currentSessionId: String? = null
    private var sessionStartTime: Long = 0
    private var lastActivityTime: Long = 0
    @Volatile
    private var _isSampled: Boolean = true

    fun start(): String {
        synchronized(lock) {
            return lockedStart()
        }
    }

    private fun lockedStart(): String {
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
                _isSampled = stored.isSampled
                logger.debug("Restored session: $currentSessionId")
                return currentSessionId!!
            }
        }

        return lockedCreateNewSession()
    }

    fun getSessionId(): String {
        synchronized(lock) {
            if (currentSessionId == null) {
                return lockedStart()
            }

            // Check if session needs rotation
            val now = System.currentTimeMillis()
            if (now - sessionStartTime > config.maxSessionDurationMs ||
                now - lastActivityTime > config.sessionTimeoutMs
            ) {
                return lockedCreateNewSession()
            }

            lastActivityTime = now
            if (config.persistent) {
                store.saveSession(StoredSession(currentSessionId!!, sessionStartTime, _isSampled))
            }

            return currentSessionId!!
        }
    }

    fun isSampled(): Boolean = _isSampled

    fun setSessionId(sessionId: String) {
        synchronized(lock) {
            currentSessionId = sessionId
            sessionStartTime = System.currentTimeMillis()
            lastActivityTime = sessionStartTime
            _isSampled = true
            if (config.persistent) {
                store.saveSession(StoredSession(sessionId, sessionStartTime, _isSampled))
            }
        }
    }

    private fun lockedCreateNewSession(): String {
        currentSessionId = generateSessionId()
        sessionStartTime = System.currentTimeMillis()
        lastActivityTime = sessionStartTime
        _isSampled = Math.random() < config.samplingRate

        if (config.persistent) {
            store.saveSession(StoredSession(currentSessionId!!, sessionStartTime, _isSampled))
        }

        logger.debug("Created new session: $currentSessionId (sampled: $_isSampled)")
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
