import Foundation

public struct SessionConfig {
    public let enabled: Bool
    public let persistent: Bool
    public let maxSessionDurationSeconds: TimeInterval
    public let sessionTimeoutSeconds: TimeInterval
    public let samplingRate: Double

    public init(
        enabled: Bool = true,
        persistent: Bool = true,
        maxSessionDurationSeconds: TimeInterval = 4 * 60 * 60,
        sessionTimeoutSeconds: TimeInterval = 15 * 60,
        samplingRate: Double = 1.0
    ) {
        self.enabled = enabled
        self.persistent = persistent
        self.maxSessionDurationSeconds = maxSessionDurationSeconds
        self.sessionTimeoutSeconds = sessionTimeoutSeconds
        self.samplingRate = samplingRate
    }
}

internal final class SessionManager {
    private let config: SessionConfig
    private let store: SessionStore
    private let logger: InternalLogger
    private let lock = NSLock()

    private var currentSessionId: String?
    private var sessionStartTime: Date = .distantPast
    private var lastActivityTime: Date = .distantPast
    private var _isSampled: Bool = true

    var isSampled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isSampled
    }

    init(config: SessionConfig, store: SessionStore, logger: InternalLogger) {
        self.config = config
        self.store = store
        self.logger = logger
    }

    func start() -> String {
        lock.lock()
        defer { lock.unlock() }
        return lockedStart()
    }

    private func lockedStart() -> String {
        guard config.enabled else {
            logger.debug("Session tracking disabled")
            return ""
        }

        if config.persistent, let stored = store.loadSession(), !isExpired(stored) {
            currentSessionId = stored.sessionId
            sessionStartTime = stored.startTime
            lastActivityTime = Date()
            _isSampled = stored.isSampled
            logger.debug("Restored session: \(currentSessionId ?? "")")
            return currentSessionId!
        }

        return lockedCreateNewSession()
    }

    func getSessionId() -> String {
        lock.lock()
        defer { lock.unlock() }

        if currentSessionId == nil {
            return lockedStart()
        }

        let now = Date()
        if now.timeIntervalSince(sessionStartTime) > config.maxSessionDurationSeconds ||
           now.timeIntervalSince(lastActivityTime) > config.sessionTimeoutSeconds {
            return lockedCreateNewSession()
        }

        lastActivityTime = now
        if config.persistent {
            store.saveSession(StoredSession(
                sessionId: currentSessionId!,
                startTime: sessionStartTime,
                isSampled: _isSampled
            ))
        }

        return currentSessionId!
    }

    func setSessionId(_ sessionId: String) {
        lock.lock()
        defer { lock.unlock() }

        currentSessionId = sessionId
        sessionStartTime = Date()
        lastActivityTime = sessionStartTime
        _isSampled = true
        if config.persistent {
            store.saveSession(StoredSession(sessionId: sessionId, startTime: sessionStartTime, isSampled: true))
        }
    }

    private func lockedCreateNewSession() -> String {
        let sessionId = generateSessionId()
        currentSessionId = sessionId
        sessionStartTime = Date()
        lastActivityTime = sessionStartTime
        _isSampled = Double.random(in: 0...1) < config.samplingRate

        if config.persistent {
            store.saveSession(StoredSession(sessionId: sessionId, startTime: sessionStartTime, isSampled: _isSampled))
        }

        logger.debug("Created new session: \(sessionId) (sampled: \(_isSampled))")
        return sessionId
    }

    private func isExpired(_ stored: StoredSession) -> Bool {
        return Date().timeIntervalSince(stored.startTime) > config.maxSessionDurationSeconds
    }

    private func generateSessionId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
    }
}
