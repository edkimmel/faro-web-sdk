package com.edkimmel.faro.session

import android.content.Context
import android.content.SharedPreferences

data class StoredSession(
    val sessionId: String,
    val startTime: Long,
    val isSampled: Boolean
)

internal class SessionStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("faro_session", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_SESSION_ID = "session_id"
        private const val KEY_START_TIME = "start_time"
        private const val KEY_IS_SAMPLED = "is_sampled"
    }

    fun saveSession(session: StoredSession) {
        prefs.edit()
            .putString(KEY_SESSION_ID, session.sessionId)
            .putLong(KEY_START_TIME, session.startTime)
            .putBoolean(KEY_IS_SAMPLED, session.isSampled)
            .apply()
    }

    fun loadSession(): StoredSession? {
        val sessionId = prefs.getString(KEY_SESSION_ID, null) ?: return null
        val startTime = prefs.getLong(KEY_START_TIME, 0)
        val isSampled = prefs.getBoolean(KEY_IS_SAMPLED, true)
        return StoredSession(sessionId, startTime, isSampled)
    }

    fun clear() {
        prefs.edit().clear().apply()
    }
}
