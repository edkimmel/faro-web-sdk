import Foundation
import os.log

public enum InternalLoggerLevel: Int, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warn = 3
    case error = 4
    case none = 5

    public static func < (lhs: InternalLoggerLevel, rhs: InternalLoggerLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

internal final class InternalLogger {
    private let level: InternalLoggerLevel
    private let logger = OSLog(subsystem: "com.grafana.faro", category: "Faro")

    init(level: InternalLoggerLevel = .error) {
        self.level = level
    }

    func verbose(_ message: String) {
        guard level <= .verbose else { return }
        os_log(.debug, log: logger, "%{public}@", message)
    }

    func debug(_ message: String) {
        guard level <= .debug else { return }
        os_log(.debug, log: logger, "%{public}@", message)
    }

    func info(_ message: String) {
        guard level <= .info else { return }
        os_log(.info, log: logger, "%{public}@", message)
    }

    func warn(_ message: String) {
        guard level <= .warn else { return }
        os_log(.default, log: logger, "WARN: %{public}@", message)
    }

    func error(_ message: String, error: Error? = nil) {
        guard level <= .error else { return }
        if let error = error {
            os_log(.error, log: logger, "%{public}@: %{public}@", message, error.localizedDescription)
        } else {
            os_log(.error, log: logger, "%{public}@", message)
        }
    }
}
