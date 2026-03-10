import Foundation

/// Faro iOS SDK - Singleton entry point.
///
/// Initialize once in your AppDelegate:
/// ```swift
/// Faro.shared.initialize(config: FaroConfig(
///     collectorUrl: "https://your-collector.example.com/collect",
///     app: MetaApp(name: "MyApp", version: "1.0.0")
/// ))
/// ```
///
/// Signals can be sent at any time — before or after initialization:
/// ```swift
/// // These are buffered to disk if sent before initialize()
/// Faro.shared.pushLog("App woke for background fetch")
/// Faro.shared.pushEvent("background_update_check")
///
/// // After initialize(), signals go directly through the SDK
/// Faro.shared.pushLog("User tapped login")
/// ```
///
/// Pre-init buffered signals are automatically replayed when initialize() is called.
public final class Faro {
    public static let shared = Faro()

    private var instance: FaroInstance?
    private let lock = NSLock()
    private let preInitBuffer = PreInitBuffer.shared

    private init() {}

    /// Configure the pre-initialization buffer before the SDK is initialized.
    /// Call this early (e.g., in AppDelegate) if you need custom buffer settings.
    /// If not called, the default PreInitBufferConfig is used.
    public func configurePreInitBuffer(_ config: PreInitBufferConfig) {
        preInitBuffer.configure(config)
    }

    /// Initialize the Faro SDK. Should be called once, typically in AppDelegate.
    ///
    /// Any signals buffered before initialization are automatically replayed through
    /// the SDK after startup completes.
    ///
    /// - Parameter config: The Faro configuration
    /// - Returns: The initialized FaroInstance
    /// - Throws: `HttpTransportError.invalidCollectorUrl` if the collector URL is malformed
    @discardableResult
    public func initialize(config: FaroConfig) throws -> FaroInstance {
        lock.lock()
        defer { lock.unlock() }

        if let existing = instance {
            let logger = InternalLogger(level: config.internalLoggerLevel)
            logger.warn("Faro is already initialized. Returning existing instance.")
            return existing
        }

        // Apply pre-init buffer config if provided
        if let preInitConfig = config.preInitBufferConfig {
            preInitBuffer.configure(preInitConfig)
        }

        let logger = InternalLogger(level: config.internalLoggerLevel)
        let faroInstance = try FaroInstance(config: config, logger: logger)
        faroInstance.start()
        // Only set instance after start() succeeds
        instance = faroInstance

        // Replay any pre-init buffered signals
        replayPreInitBuffer(instance: faroInstance, logger: logger)

        return faroInstance
    }

    /// Get the initialized Faro instance, if available.
    ///
    /// - Returns: The FaroInstance, or nil if not yet initialized
    public func getInstance() -> FaroInstance? {
        return instance
    }

    /// Check if Faro has been initialized.
    public var isInitialized: Bool {
        return instance != nil
    }

    /// Shutdown and reset the Faro SDK. Primarily for testing.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        instance?.shutdown()
        instance = nil
    }

    // MARK: - Convenience methods (buffer if not initialized, forward if initialized)

    /// Push a log signal. Buffers to disk if the SDK is not yet initialized.
    public func pushLog(
        _ message: String,
        level: LogLevel = .log,
        context: [String: String]? = nil
    ) {
        if let instance = instance {
            instance.pushLog(message, level: level, context: context)
        } else {
            preInitBuffer.bufferLog(message: message, level: level, context: context)
        }
    }

    /// Push an error signal. Buffers to disk if the SDK is not yet initialized.
    public func pushError(
        type: String,
        value: String,
        stacktrace: Stacktrace? = nil,
        context: [String: String]? = nil
    ) {
        if let instance = instance {
            instance.pushError(type: type, value: value, stacktrace: stacktrace, context: context)
        } else {
            preInitBuffer.bufferError(type: type, value: value, stacktrace: stacktrace, context: context)
        }
    }

    /// Push an error signal from an Error. Buffers to disk if the SDK is not yet initialized.
    public func pushError(_ error: Error, context: [String: String]? = nil) {
        if let instance = instance {
            instance.pushError(error, context: context)
        } else {
            let nsError = error as NSError
            preInitBuffer.bufferError(
                type: nsError.domain,
                value: nsError.localizedDescription,
                context: context
            )
        }
    }

    /// Push a measurement signal. Buffers to disk if the SDK is not yet initialized.
    public func pushMeasurement(
        type: String,
        values: [String: Double],
        context: [String: String]? = nil
    ) {
        if let instance = instance {
            instance.pushMeasurement(type: type, values: values, context: context)
        } else {
            preInitBuffer.bufferMeasurement(type: type, values: values, context: context)
        }
    }

    /// Push a custom event. Buffers to disk if the SDK is not yet initialized.
    public func pushEvent(
        _ name: String,
        attributes: [String: String]? = nil,
        domain: String? = nil
    ) {
        if let instance = instance {
            instance.pushEvent(name, attributes: attributes, domain: domain)
        } else {
            preInitBuffer.bufferEvent(name: name, attributes: attributes, domain: domain)
        }
    }

    // MARK: - Pre-init replay

    private func replayPreInitBuffer(instance: FaroInstance, logger: InternalLogger) {
        let entries = preInitBuffer.readPendingEntries()
        guard !entries.isEmpty else { return }

        logger.info("Replaying \(entries.count) pre-init buffered signal(s)")

        for entry in entries {
            switch entry.signalType {
            case "log":
                if let data = entry.log {
                    instance.replayLog(
                        data.message,
                        level: LogLevel.fromString(data.level),
                        context: data.context,
                        timestamp: entry.timestamp
                    )
                }
            case "exception":
                if let data = entry.exception {
                    instance.replayError(
                        type: data.type,
                        value: data.value,
                        stacktrace: data.stacktrace,
                        context: data.context,
                        timestamp: entry.timestamp
                    )
                }
            case "measurement":
                if let data = entry.measurement {
                    instance.replayMeasurement(
                        type: data.type,
                        values: data.values,
                        context: data.context,
                        timestamp: entry.timestamp
                    )
                }
            case "event":
                if let data = entry.event {
                    instance.replayEvent(
                        data.name,
                        attributes: data.attributes,
                        domain: data.domain,
                        timestamp: entry.timestamp
                    )
                }
            default:
                logger.warn("Unknown pre-init signal type: \(entry.signalType)")
            }
        }

        preInitBuffer.clear()
        logger.info("Pre-init buffer replay complete")
    }
}
