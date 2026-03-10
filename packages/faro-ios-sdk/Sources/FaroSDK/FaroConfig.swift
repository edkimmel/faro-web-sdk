import Foundation

public struct FaroConfig {
    public let collectorUrl: String
    public let app: MetaApp
    public let apiKey: String?
    public let user: MetaUser?
    public let sessionTracking: SessionConfig
    public let enableCrashReporting: Bool
    public let enableHangDetection: Bool
    public let enableLifecycleTracking: Bool
    public let enableNetworkMonitoring: Bool
    public let batchConfig: BatchConfig
    public let diskBufferConfig: DiskBufferConfig
    public let internalLoggerLevel: InternalLoggerLevel
    public let beforeSend: ((TransportItem) -> TransportItem?)?
    public let ignoreErrors: [NSRegularExpression]
    public let ignoreUrls: [NSRegularExpression]
    public let eventDomain: String
    /// Whether to use beginBackgroundTask to protect uploads from suspension.
    /// When true, the SDK requests additional background execution time (~30s) during uploads.
    public let backgroundTasksEnabled: Bool
    /// Set to true when running inside an app extension (widget, notification service, etc.)
    /// where UIApplication is unavailable.
    public let isRunFromExtension: Bool
    /// Configuration for the pre-initialization buffer. When nil, defaults are used.
    /// The pre-init buffer captures signals sent before initialize() and replays them
    /// when the SDK starts.
    public let preInitBufferConfig: PreInitBufferConfig?

    public init(
        collectorUrl: String,
        app: MetaApp,
        apiKey: String? = nil,
        user: MetaUser? = nil,
        sessionTracking: SessionConfig = SessionConfig(),
        enableCrashReporting: Bool = false,
        enableHangDetection: Bool = true,
        enableLifecycleTracking: Bool = true,
        enableNetworkMonitoring: Bool = true,
        batchConfig: BatchConfig = BatchConfig(),
        diskBufferConfig: DiskBufferConfig = DiskBufferConfig(),
        internalLoggerLevel: InternalLoggerLevel = .error,
        beforeSend: ((TransportItem) -> TransportItem?)? = nil,
        ignoreErrors: [NSRegularExpression] = [],
        ignoreUrls: [NSRegularExpression] = [],
        eventDomain: String = "app",
        backgroundTasksEnabled: Bool = true,
        isRunFromExtension: Bool = false,
        preInitBufferConfig: PreInitBufferConfig? = nil
    ) {
        self.collectorUrl = collectorUrl
        self.app = app
        self.apiKey = apiKey
        self.user = user
        self.sessionTracking = sessionTracking
        self.enableCrashReporting = enableCrashReporting
        self.enableHangDetection = enableHangDetection
        self.enableLifecycleTracking = enableLifecycleTracking
        self.enableNetworkMonitoring = enableNetworkMonitoring
        self.batchConfig = batchConfig
        self.diskBufferConfig = diskBufferConfig
        self.internalLoggerLevel = internalLoggerLevel
        self.beforeSend = beforeSend
        self.ignoreErrors = ignoreErrors
        self.ignoreUrls = ignoreUrls
        self.eventDomain = eventDomain
        self.backgroundTasksEnabled = backgroundTasksEnabled
        self.isRunFromExtension = isRunFromExtension
        self.preInitBufferConfig = preInitBufferConfig
    }
}
