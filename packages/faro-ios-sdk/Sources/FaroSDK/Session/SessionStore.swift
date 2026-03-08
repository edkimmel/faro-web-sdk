import Foundation

internal struct StoredSession {
    let sessionId: String
    let startTime: Date
    let isSampled: Bool
}

internal final class SessionStore {
    private let defaults: UserDefaults

    private enum Keys {
        static let sessionId = "com.grafana.faro.session.id"
        static let startTime = "com.grafana.faro.session.startTime"
        static let isSampled = "com.grafana.faro.session.isSampled"
    }

    init(suiteName: String? = nil) {
        if let suiteName = suiteName {
            self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            self.defaults = .standard
        }
    }

    func saveSession(_ session: StoredSession) {
        defaults.set(session.sessionId, forKey: Keys.sessionId)
        defaults.set(session.startTime.timeIntervalSince1970, forKey: Keys.startTime)
        defaults.set(session.isSampled, forKey: Keys.isSampled)
    }

    func loadSession() -> StoredSession? {
        guard let sessionId = defaults.string(forKey: Keys.sessionId) else { return nil }
        let startTime = Date(timeIntervalSince1970: defaults.double(forKey: Keys.startTime))
        let isSampled = defaults.bool(forKey: Keys.isSampled)
        return StoredSession(sessionId: sessionId, startTime: startTime, isSampled: isSampled)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.sessionId)
        defaults.removeObject(forKey: Keys.startTime)
        defaults.removeObject(forKey: Keys.isSampled)
    }
}
