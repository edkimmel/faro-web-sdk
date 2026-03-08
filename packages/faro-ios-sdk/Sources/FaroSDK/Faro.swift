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
/// Faro.shared.getInstance().pushLog("Something happened")
/// Faro.shared.getInstance().pushError(error)
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
    @discardableResult
    public func initialize(config: FaroConfig) -> FaroInstance {
        lock.lock()
        defer { lock.unlock() }

        guard instance == nil else {
            fatalError("Faro is already initialized. Call Faro.shared.getInstance() to access the existing instance.")
        }

        let logger = InternalLogger(level: config.internalLoggerLevel)
        let faroInstance = FaroInstance(config: config, logger: logger)
        instance = faroInstance
        faroInstance.start()
        return faroInstance
    }

    /// Get the initialized Faro instance.
    ///
    /// - Returns: The FaroInstance
    public func getInstance() -> FaroInstance {
        guard let instance = instance else {
            fatalError("Faro has not been initialized. Call Faro.shared.initialize() first.")
        }
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
