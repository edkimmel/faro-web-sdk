import Foundation

/// Configuration for the pre-initialization buffer.
public struct PreInitBufferConfig {
    /// Maximum disk usage for pre-init buffered signals.
    public let maxDiskUsageBytes: Int64

    /// Maximum age of buffered signals before they are discarded.
    public let maxFileAgeSeconds: TimeInterval

    /// Directory name within the Faro cache directory.
    public let dirName: String

    public init(
        maxDiskUsageBytes: Int64 = 1 * 1024 * 1024,
        maxFileAgeSeconds: TimeInterval = 72 * 60 * 60,
        dirName: String = "faro_pre_init"
    ) {
        self.maxDiskUsageBytes = maxDiskUsageBytes
        self.maxFileAgeSeconds = maxFileAgeSeconds
        self.dirName = dirName
    }
}

/// A lightweight, static disk buffer for capturing signals before the SDK is initialized.
///
/// Signals are written as individual JSON files to a known directory. When the SDK
/// initializes, it reads these files, replays them through the normal pipeline, and
/// deletes them.
///
/// This is intentionally simple — no session, user, or device meta is attached at
/// write time. Meta is attached during replay when the full SDK context is available.
internal final class PreInitBuffer {
    static let shared = PreInitBuffer()

    private let fileManager = FileManager.default
    private let writeQueue = DispatchQueue(label: "com.edkimmel.faro.preinitbuffer")
    private var config = PreInitBufferConfig()
    private var bufferDir: URL

    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        bufferDir = cacheDir.appendingPathComponent("faro").appendingPathComponent(config.dirName)
        try? fileManager.createDirectory(at: bufferDir, withIntermediateDirectories: true)
    }

    func configure(_ config: PreInitBufferConfig) {
        writeQueue.sync {
            self.config = config
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.bufferDir = cacheDir.appendingPathComponent("faro").appendingPathComponent(config.dirName)
            try? self.fileManager.createDirectory(at: self.bufferDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Write methods

    func bufferLog(message: String, level: LogLevel, context: [String: String]? = nil) {
        let entry = PreInitEntry(
            signalType: "log",
            timestamp: Clock.nowTimestamp(),
            log: PreInitLogData(message: message, level: level.rawValue, context: context)
        )
        writeEntry(entry)
    }

    func bufferError(type: String, value: String, stacktrace: Stacktrace? = nil, context: [String: String]? = nil) {
        let entry = PreInitEntry(
            signalType: "exception",
            timestamp: Clock.nowTimestamp(),
            exception: PreInitExceptionData(type: type, value: value, stacktrace: stacktrace, context: context)
        )
        writeEntry(entry)
    }

    func bufferMeasurement(type: String, values: [String: Double], context: [String: String]? = nil) {
        let entry = PreInitEntry(
            signalType: "measurement",
            timestamp: Clock.nowTimestamp(),
            measurement: PreInitMeasurementData(type: type, values: values, context: context)
        )
        writeEntry(entry)
    }

    func bufferEvent(name: String, attributes: [String: String]? = nil, domain: String? = nil) {
        let entry = PreInitEntry(
            signalType: "event",
            timestamp: Clock.nowTimestamp(),
            event: PreInitEventData(name: name, domain: domain, attributes: attributes)
        )
        writeEntry(entry)
    }

    // MARK: - Read and replay

    func readPendingEntries() -> [PreInitEntry] {
        enforceStorageLimits()

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                guard let entry = try? JSONDecoder().decode(PreInitEntry.self, from: data) else {
                    try? fileManager.removeItem(at: url)
                    return nil
                }
                return entry
            }
    }

    func clear() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }
        for url in fileURLs {
            try? fileManager.removeItem(at: url)
        }
    }

    var isEmpty: Bool {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return true
        }
        return contents.isEmpty
    }

    // MARK: - Private

    private func writeEntry(_ entry: PreInitEntry) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            self.enforceStorageLimits()

            let fileName = "\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).json"
            let fileURL = self.bufferDir.appendingPathComponent(fileName)

            do {
                let data = try JSONEncoder().encode(entry)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Best effort — no logger available pre-init
            }
        }
    }

    private func enforceStorageLimits() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let now = Date()

        // Delete expired files
        for url in fileURLs {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let modDate = attrs[.modificationDate] as? Date,
               now.timeIntervalSince(modDate) > config.maxFileAgeSeconds {
                try? fileManager.removeItem(at: url)
            }
        }

        // Enforce size limit
        guard let remaining = try? fileManager.contentsOfDirectory(
            at: bufferDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let sorted = remaining.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var totalSize: Int64 = 0
        for url in sorted {
            if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        if totalSize > config.maxDiskUsageBytes {
            for url in sorted {
                guard totalSize > config.maxDiskUsageBytes else { break }
                if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    try? fileManager.removeItem(at: url)
                    totalSize -= size
                }
            }
        }
    }
}

// MARK: - Pre-init entry models

internal struct PreInitEntry: Codable {
    let signalType: String
    let timestamp: String
    let log: PreInitLogData?
    let exception: PreInitExceptionData?
    let measurement: PreInitMeasurementData?
    let event: PreInitEventData?

    init(
        signalType: String,
        timestamp: String,
        log: PreInitLogData? = nil,
        exception: PreInitExceptionData? = nil,
        measurement: PreInitMeasurementData? = nil,
        event: PreInitEventData? = nil
    ) {
        self.signalType = signalType
        self.timestamp = timestamp
        self.log = log
        self.exception = exception
        self.measurement = measurement
        self.event = event
    }
}

internal struct PreInitLogData: Codable {
    let message: String
    let level: String
    let context: [String: String]?
}

internal struct PreInitExceptionData: Codable {
    let type: String
    let value: String
    let stacktrace: Stacktrace?
    let context: [String: String]?
}

internal struct PreInitMeasurementData: Codable {
    let type: String
    let values: [String: Double]
    let context: [String: String]?
}

internal struct PreInitEventData: Codable {
    let name: String
    let domain: String?
    let attributes: [String: String]?
}
