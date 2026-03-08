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

    private var currentSessionId: String?
    private var sessionStartTime: Date = .distantPast
    private var lastActivityTime: Date = .distantPast
    private(set) var isSampled: Bool = true

    init(config: SessionConfig, store: SessionStore, logger: InternalLogger) {
        self.config = config
        self.store = store
        self.logger = logger
    }

    func start() -> String {
        guard config.enabled else {
            logger.debug("Session tracking disabled")
            return ""
        }

        if config.persistent, let stored = store.loadSession(), !isExpired(stored) {
            currentSessionId = stored.sessionId
            sessionStartTime = stored.startTime
            lastActivityTime = Date()
            isSampled = stored.isSampled
            logger.debug("Restored session: \(currentSessionId ?? "")")
            return currentSessionId!
        }

        return createNewSession()
    }

    func getSessionId() -> String {
        if currentSessionId == nil {
            return start()
        }

        let now = Date()
        if now.timeIntervalSince(sessionStartTime) > config.maxSessionDurationSeconds ||
           now.timeIntervalSince(lastActivityTime) > config.sessionTimeoutSeconds {
            return createNewSession()
        }

        lastActivityTime = now
        if config.persistent {
            store.saveSession(StoredSession(
                sessionId: currentSessionId!,
                startTime: sessionStartTime,
                isSampled: isSampled
            ))
        }

        return currentSessionId!
    }

    func setSessionId(_ sessionId: String) {
        currentSessionId = sessionId
        sessionStartTime = Date()
        lastActivityTime = sessionStartTime
        isSampled = true
        if config.persistent {
            store.saveSession(StoredSession(sessionId: sessionId, startTime: sessionStartTime, isSampled: true))
        }
    }

    private func createNewSession() -> String {
        let sessionId = generateSessionId()
        currentSessionId = sessionId
        sessionStartTime = Date()
        lastActivityTime = sessionStartTime
        isSampled = Double.random(in: 0...1) < config.samplingRate

        if config.persistent {
            store.saveSession(StoredSession(sessionId: sessionId, startTime: sessionStartTime, isSampled: isSampled))
        }

        logger.debug("Created new session: \(sessionId) (sampled: \(isSampled))")
        return sessionId
    }

    private func isExpired(_ stored: StoredSession) -> Bool {
        return Date().timeIntervalSince(stored.startTime) > config.maxSessionDurationSeconds
    }

    private func generateSessionId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16).lowercased()
    }
}
