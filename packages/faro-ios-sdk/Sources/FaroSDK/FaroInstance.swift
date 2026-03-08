import Foundation
import UIKit

public final class FaroInstance {
    public let config: FaroConfig

    private let logger: InternalLogger
    private let sessionManager: SessionManager
    private let diskBuffer: DiskBuffer
    private let httpTransport: HttpTransport
    private let diskBufferTransport: DiskBufferTransport
    private var batchExecutor: BatchExecutor!
    private let instrumentationsQueue = DispatchQueue(label: "com.grafana.faro.instance.instrumentations")
    private var _instrumentations: [Instrumentation] = []
    private var instrumentations: [Instrumentation] {
        get { instrumentationsQueue.sync { _instrumentations } }
    }

    private let stateQueue = DispatchQueue(label: "com.grafana.faro.instance.state")
    private var _isPaused = false
    private var _currentUser: MetaUser?
    private var _currentView: MetaView?

    private var isPaused: Bool {
        get { stateQueue.sync { _isPaused } }
        set { stateQueue.sync { _isPaused = newValue } }
    }
    private var currentUser: MetaUser? {
        get { stateQueue.sync { _currentUser } }
        set { stateQueue.sync { _currentUser = newValue } }
    }
    private var currentView: MetaView? {
        get { stateQueue.sync { _currentView } }
        set { stateQueue.sync { _currentView = newValue } }
    }

    static let sdkName = "faro-ios-sdk"
    static let sdkVersion = "1.0.0"

    init(config: FaroConfig, logger: InternalLogger) throws {
        self.config = config
        self.logger = logger
        self._currentUser = config.user

        let sessionStore = SessionStore()
        sessionManager = SessionManager(config: config.sessionTracking, store: sessionStore, logger: logger)

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let faroDir = cacheDir.appendingPathComponent("faro")
        diskBuffer = DiskBuffer(baseDir: faroDir, config: config.diskBufferConfig, logger: logger)

        httpTransport = try HttpTransport(
            collectorUrl: config.collectorUrl,
            apiKey: config.apiKey,
            logger: logger
        )

        diskBufferTransport = DiskBufferTransport(
            diskBuffer: diskBuffer,
            httpTransport: httpTransport,
            logger: logger
        )

        batchExecutor = BatchExecutor(
            config: config.batchConfig,
            logger: logger,
            onFlush: { [weak self] items in self?.flushItems(items) }
        )
    }

    func start() {
        logger.info("Starting Faro SDK")

        _ = sessionManager.start()
        diskBufferTransport.start()

        if config.enableLifecycleTracking {
            installInstrumentation(AppLifecycleInstrumentation())
        }

        if config.enableCrashReporting {
            installInstrumentation(CrashInstrumentation())
        }

        if config.enableHangDetection {
            installInstrumentation(HangInstrumentation())
        }

        if config.enableNetworkMonitoring {
            installInstrumentation(URLSessionInstrumentation())
        }

        logger.info("Faro SDK started")
    }

    public func installInstrumentation(_ instrumentation: Instrumentation) {
        instrumentation.install(faro: self)
        instrumentationsQueue.sync { _instrumentations.append(instrumentation) }
        logger.debug("Installed instrumentation: \(instrumentation.name)")
    }

    // MARK: - Public API

    public func pushLog(
        _ message: String,
        level: LogLevel = .log,
        context: [String: String]? = nil,
        traceContext: TraceContext? = nil
    ) {
        guard !isPaused, sessionManager.isSampled else { return }
        guard !shouldIgnoreError(message) else { return }

        let event = LogEvent(
            message: message,
            level: level,
            timestamp: Clock.nowTimestamp(),
            context: context,
            trace: traceContext
        )

        enqueue(type: .log, payload: event)
    }

    public func pushError(_ error: Error, context: [String: String]? = nil, traceContext: TraceContext? = nil) {
        let nsError = error as NSError
        pushError(
            type: nsError.domain,
            value: nsError.localizedDescription,
            context: context,
            traceContext: traceContext
        )
    }

    public func pushError(
        type: String,
        value: String,
        stacktrace: Stacktrace? = nil,
        context: [String: String]? = nil,
        traceContext: TraceContext? = nil
    ) {
        guard !isPaused, sessionManager.isSampled else { return }
        guard !shouldIgnoreError(value) else { return }

        let event = ExceptionEvent(
            type: type,
            value: value,
            timestamp: Clock.nowTimestamp(),
            stacktrace: stacktrace,
            context: context,
            trace: traceContext
        )

        enqueue(type: .exception, payload: event)
    }

    public func pushMeasurement(
        type: String,
        values: [String: Double],
        context: [String: String]? = nil,
        traceContext: TraceContext? = nil
    ) {
        guard !isPaused, sessionManager.isSampled else { return }

        let event = MeasurementEvent(
            type: type,
            values: values,
            timestamp: Clock.nowTimestamp(),
            context: context,
            trace: traceContext
        )

        enqueue(type: .measurement, payload: event)
    }

    public func pushEvent(
        _ name: String,
        attributes: [String: String]? = nil,
        domain: String? = nil,
        traceContext: TraceContext? = nil
    ) {
        guard !isPaused, sessionManager.isSampled else { return }

        let event = EventEvent(
            name: name,
            timestamp: Clock.nowTimestamp(),
            domain: domain ?? config.eventDomain,
            attributes: attributes,
            trace: traceContext
        )

        enqueue(type: .event, payload: event)
    }

    public func setUser(_ user: MetaUser?) {
        currentUser = user
    }

    public func resetUser() {
        currentUser = nil
    }

    public func setView(_ viewName: String) {
        currentView = MetaView(name: viewName)
    }

    public func setSession(_ sessionId: String) {
        sessionManager.setSessionId(sessionId)
    }

    public func getSessionId() -> String {
        return sessionManager.getSessionId()
    }

    public func pause() {
        isPaused = true
        batchExecutor.isPaused = true
    }

    public func unpause() {
        isPaused = false
        batchExecutor.isPaused = false
    }

    public func flush() {
        batchExecutor.flush()
    }

    public func shutdown() {
        let currentInstrumentations = instrumentations
        currentInstrumentations.forEach { $0.uninstall() }
        instrumentationsQueue.sync { _instrumentations.removeAll() }
        batchExecutor.shutdown()
        diskBufferTransport.shutdown()
    }

    // MARK: - Internal

    internal func writeCrashToDisk(_ exception: ExceptionEvent) {
        let body = TransportBody(
            meta: buildMeta(),
            exceptions: [exception]
        )
        diskBuffer.writeCrash(body)
    }

    internal func shouldIgnoreUrl(_ url: String) -> Bool {
        if url == config.collectorUrl { return true }
        return config.ignoreUrls.contains { regex in
            regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
        }
    }

    private func shouldIgnoreError(_ message: String) -> Bool {
        return config.ignoreErrors.contains { regex in
            regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) != nil
        }
    }

    private func enqueue(type: TransportItemType, payload: Any) {
        var item = TransportItem(type: type, payload: payload, meta: buildMeta())

        if let beforeSend = config.beforeSend {
            guard let processed = beforeSend(item) else {
                logger.debug("Signal dropped by beforeSend hook")
                return
            }
            item = processed
        }

        batchExecutor.add(item)
    }

    private func flushItems(_ items: [TransportItem]) {
        guard !items.isEmpty else { return }

        let meta = items.first!.meta
        var logs: [LogEvent] = []
        var exceptions: [ExceptionEvent] = []
        var measurements: [MeasurementEvent] = []
        var events: [EventEvent] = []

        for item in items {
            switch item.type {
            case .log:
                guard let event = item.payload as? LogEvent else {
                    logger.error("Unexpected payload type for log item, skipping")
                    continue
                }
                logs.append(event)
            case .exception:
                guard let event = item.payload as? ExceptionEvent else {
                    logger.error("Unexpected payload type for exception item, skipping")
                    continue
                }
                exceptions.append(event)
            case .measurement:
                guard let event = item.payload as? MeasurementEvent else {
                    logger.error("Unexpected payload type for measurement item, skipping")
                    continue
                }
                measurements.append(event)
            case .event:
                guard let event = item.payload as? EventEvent else {
                    logger.error("Unexpected payload type for event item, skipping")
                    continue
                }
                events.append(event)
            }
        }

        let body = TransportBody(
            meta: meta,
            logs: logs.isEmpty ? nil : logs,
            exceptions: exceptions.isEmpty ? nil : exceptions,
            measurements: measurements.isEmpty ? nil : measurements,
            events: events.isEmpty ? nil : events
        )

        try? diskBufferTransport.send(body: body)
    }

    private func buildMeta() -> Meta {
        return Meta(
            sdk: MetaSDK(
                name: Self.sdkName,
                version: Self.sdkVersion,
                integrations: instrumentations.map { MetaSDKIntegration(name: $0.name) }
            ),
            app: config.app,
            user: currentUser,
            session: MetaSession(id: sessionManager.getSessionId()),
            view: currentView,
            device: buildDeviceMeta()
        )
    }

    private func buildDeviceMeta() -> MetaDevice {
        let screen = UIScreen.main
        let bundle = Bundle.main
        return MetaDevice(
            platform: "ios",
            osName: "iOS",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: deviceModel(),
            deviceManufacturer: "Apple",
            screenWidth: Int(screen.bounds.width * screen.scale),
            screenHeight: Int(screen.bounds.height * screen.scale),
            screenDensity: Float(screen.scale),
            isEmulator: isSimulator(),
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            appBuildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String
        )
    }

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    private func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
