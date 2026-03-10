import Foundation

internal enum Clock {
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func nowTimestamp() -> String {
        return isoFormatter.string(from: Date())
    }

    static func nowMillis() -> Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
}
