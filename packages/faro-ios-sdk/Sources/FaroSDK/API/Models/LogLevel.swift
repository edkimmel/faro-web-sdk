import Foundation

public enum LogLevel: String, Codable {
    case trace
    case debug
    case info
    case log
    case warn
    case error

    public static func fromString(_ value: String) -> LogLevel {
        return LogLevel(rawValue: value.lowercased()) ?? .log
    }
}
