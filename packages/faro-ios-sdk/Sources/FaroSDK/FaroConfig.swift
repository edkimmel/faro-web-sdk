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
        eventDomain: String = "app"
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
    }
}
