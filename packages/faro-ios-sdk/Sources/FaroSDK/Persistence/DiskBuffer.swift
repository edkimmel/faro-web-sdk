import Foundation

public struct DiskBufferConfig {
    public let maxDiskUsageBytes: Int64
    public let maxFileAgeSeconds: TimeInterval
    public let signalsDir: String
    public let crashDir: String

    public init(
        maxDiskUsageBytes: Int64 = 5 * 1024 * 1024,
        maxFileAgeSeconds: TimeInterval = 24 * 60 * 60,
        signalsDir: String = "faro_signals",
        crashDir: String = "faro_crashes"
    ) {
        self.maxDiskUsageBytes = maxDiskUsageBytes
        self.maxFileAgeSeconds = maxFileAgeSeconds
        self.signalsDir = signalsDir
        self.crashDir = crashDir
    }
}

internal final class DiskBuffer {
    private let signalsDir: URL
    private let crashDir: URL
    private let config: DiskBufferConfig
    private let logger: InternalLogger
    private let fileManager = FileManager.default
    private let writeQueue = DispatchQueue(label: "com.grafana.faro.diskbuffer")

    init(baseDir: URL, config: DiskBufferConfig, logger: InternalLogger) {
        self.config = config
        self.logger = logger
        self.signalsDir = baseDir.appendingPathComponent(config.signalsDir)
        self.crashDir = baseDir.appendingPathComponent(config.crashDir)

        try? fileManager.createDirectory(at: signalsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: crashDir, withIntermediateDirectories: true)
    }

    func writeSignal(_ body: TransportBody) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }
            self.enforceStorageLimits()

            let fileName = "\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).json"
            let fileURL = self.signalsDir.appendingPathComponent(fileName)

            do {
                let data = try body.toJSON()
                try data.write(to: fileURL)
                self.logger.debug("Signal written to disk: \(fileName)")
            } catch {
                self.logger.error("Failed to write signal to disk", error: error)
            }
        }
    }

    func writeCrash(_ body: TransportBody) {
        // Write synchronously for crash scenarios
        let fileName = "crash_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).json"
        let fileURL = crashDir.appendingPathComponent(fileName)

        do {
            let data = try body.toJSON()
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Best effort in crash handler
        }
    }

    func readPendingSignals() -> [SignalFile] {
        return readFiles(from: signalsDir)
    }

    func readPendingCrashes() -> [SignalFile] {
        return readFiles(from: crashDir)
    }

    private func readFiles(from directory: URL) -> [SignalFile] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.nameKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                do {
                    let data = try Data(contentsOf: url)
                    let body = try TransportBody.fromJSON(data)
                    return SignalFile(url: url, body: body)
                } catch {
                    logger.error("Failed to read signal file: \(url.lastPathComponent)", error: error)
                    try? fileManager.removeItem(at: url)
                    return nil
                }
            }
    }

    func deleteFile(_ signalFile: SignalFile) {
        try? fileManager.removeItem(at: signalFile.url)
    }

    func enforceStorageLimits() {
        let now = Date()

        // Delete old files
        let allFiles = getAllFileURLs()
        for fileURL in allFiles {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let modDate = attrs[.modificationDate] as? Date,
               now.timeIntervalSince(modDate) > config.maxFileAgeSeconds {
                try? fileManager.removeItem(at: fileURL)
                logger.debug("Deleted expired signal file: \(fileURL.lastPathComponent)")
            }
        }

        // Enforce total size limit
        var totalSize: Int64 = 0
        let sortedFiles = getAllFileURLs().sorted { url1, url2 in
            let date1 = (try? fileManager.attributesOfItem(atPath: url1.path)[.modificationDate] as? Date) ?? .distantPast
            let date2 = (try? fileManager.attributesOfItem(atPath: url2.path)[.modificationDate] as? Date) ?? .distantPast
            return date1 < date2
        }

        for fileURL in sortedFiles {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }

        if totalSize > config.maxDiskUsageBytes {
            for fileURL in sortedFiles {
                guard totalSize > config.maxDiskUsageBytes else { break }
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    try? fileManager.removeItem(at: fileURL)
                    totalSize -= size
                    logger.debug("Deleted signal file to enforce size limit: \(fileURL.lastPathComponent)")
                }
            }
        }
    }

    private func getAllFileURLs() -> [URL] {
        let signalFiles = (try? fileManager.contentsOfDirectory(
            at: signalsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        let crashFiles = (try? fileManager.contentsOfDirectory(
            at: crashDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []
        return signalFiles + crashFiles
    }

    func clear() {
        let allFiles = getAllFileURLs()
        for fileURL in allFiles {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
