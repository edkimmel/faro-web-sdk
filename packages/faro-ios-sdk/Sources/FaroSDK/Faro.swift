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
/// Then access from anywhere:
/// ```swift
/// Faro.shared.getInstance()?.pushLog("Something happened")
/// Faro.shared.getInstance()?.pushError(error)
/// ```
public final class Faro {
    public static let shared = Faro()

    private var instance: FaroInstance?
    private let lock = NSLock()

    private init() {}

    /// Initialize the Faro SDK. Should be called once, typically in AppDelegate.
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

        let logger = InternalLogger(level: config.internalLoggerLevel)
        let faroInstance = try FaroInstance(config: config, logger: logger)
        faroInstance.start()
        // Only set instance after start() succeeds
        instance = faroInstance
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
}
