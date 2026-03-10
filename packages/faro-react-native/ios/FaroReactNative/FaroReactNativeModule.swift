import Foundation
import os.log
import FaroSDK

@objc(FaroReactNative)
class FaroReactNativeModule: NSObject {
    private let instanceQueue = DispatchQueue(label: "com.edkimmel.faro.reactnative.instance")
    private var _faroInstance: FaroInstance?
    private var faroInstance: FaroInstance? {
        get { instanceQueue.sync { _faroInstance } }
        set { instanceQueue.sync { _faroInstance = newValue } }
    }
    private let logger = OSLog(subsystem: "com.edkimmel.faro.reactnative", category: "Bridge")

    @objc
    func initialize(_ configJson: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        os_log(.info, log: logger, "initialize() called")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let config = try self.parseConfig(configJson)
                os_log(.info, log: self.logger, "Config parsed — collectorUrl=%{public}@", config.collectorUrl)
                self.faroInstance = try Faro.shared.initialize(config: config)
                os_log(.info, log: self.logger, "Native SDK initialized successfully")
                resolve(nil)
            } catch {
                os_log(.error, log: self.logger, "initialize() failed: %{public}@", error.localizedDescription)
                reject("FARO_INIT_ERROR", error.localizedDescription, error)
            }
        }
    }

    private func ensureInstance(_ caller: String) -> FaroInstance? {
        guard let instance = faroInstance else {
            os_log(.fault, log: logger, "%{public}@ called but native SDK not initialized — dropping signal", caller)
            return nil
        }
        return instance
    }

    @objc
    func pushLog(_ level: String, message: String, context: String?, timestamp: String?) {
        guard let instance = ensureInstance("pushLog") else { return }
        os_log(.debug, log: logger, "pushLog(level=%{public}@, message=%{public}@)", level, String(message.prefix(80)))
        let ctx = context.flatMap { parseStringDict($0) }
        instance.pushLog(message, level: LogLevel.fromString(level), context: ctx)
    }

    @objc
    func pushError(_ type: String, value: String, stacktrace: String?, context: String?) {
        guard let instance = ensureInstance("pushError") else { return }
        os_log(.debug, log: logger, "pushError(type=%{public}@, value=%{public}@)", type, String(value.prefix(80)))
        let ctx = context.flatMap { parseStringDict($0) }
        let st = stacktrace.flatMap { parseStacktrace($0) }
        instance.pushError(type: type, value: value, stacktrace: st, context: ctx)
    }

    @objc
    func pushMeasurement(_ type: String, values: String, context: String?) {
        guard let instance = ensureInstance("pushMeasurement") else { return }
        os_log(.debug, log: logger, "pushMeasurement(type=%{public}@, values=%{public}@)", type, values)
        let parsedValues = parseDoubleDict(values)
        let ctx = context.flatMap { parseStringDict($0) }
        instance.pushMeasurement(type: type, values: parsedValues, context: ctx)
    }

    @objc
    func pushEvent(_ name: String, attributes: String?, domain: String?) {
        guard let instance = ensureInstance("pushEvent") else { return }
        os_log(.debug, log: logger, "pushEvent(name=%{public}@, domain=%{public}@)", name, domain ?? "nil")
        let attrs = attributes.flatMap { parseStringDict($0) }
        instance.pushEvent(name, attributes: attrs, domain: domain)
    }

    @objc
    func setUser(_ userJson: String) {
        guard let instance = ensureInstance("setUser") else { return }
        os_log(.debug, log: logger, "setUser()")
        if let user = parseUser(userJson) {
            instance.setUser(user)
        }
    }

    @objc
    func resetUser() {
        os_log(.debug, log: logger, "resetUser()")
        faroInstance?.resetUser()
    }

    @objc
    func setSession(_ sessionId: String) {
        os_log(.debug, log: logger, "setSession(id=%{public}@)", sessionId)
        faroInstance?.setSession(sessionId)
    }

    @objc
    func setView(_ viewName: String) {
        os_log(.debug, log: logger, "setView(name=%{public}@)", viewName)
        faroInstance?.setView(viewName)
    }

    @objc
    func pause() {
        os_log(.debug, log: logger, "pause()")
        faroInstance?.pause()
    }

    @objc
    func unpause() {
        os_log(.debug, log: logger, "unpause()")
        faroInstance?.unpause()
    }

    @objc
    func getDeviceInfo(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            let screen = UIScreen.main
            let bundle = Bundle.main
            let device = UIDevice.current

            var info: [String: Any] = [
                "platform": "ios",
                "osName": "iOS",
                "osVersion": device.systemVersion,
                "deviceModel": self.deviceModel(),
                "deviceManufacturer": "Apple",
                "screenWidth": Int(screen.bounds.width * screen.scale),
                "screenHeight": Int(screen.bounds.height * screen.scale),
                "screenDensity": Float(screen.scale),
                "appVersion": bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
                "appBuildNumber": bundle.infoDictionary?["CFBundleVersion"] as? String ?? ""
            ]

            #if targetEnvironment(simulator)
            info["isEmulator"] = true
            #else
            info["isEmulator"] = false
            #endif

            do {
                let data = try JSONSerialization.data(withJSONObject: info)
                let jsonString = String(data: data, encoding: .utf8)
                resolve(jsonString)
            } catch {
                reject("DEVICE_INFO_ERROR", error.localizedDescription, error)
            }
        }
    }

    // MARK: - Parsing Helpers

    private func parseConfig(_ jsonString: String) throws -> FaroConfig {
        guard let data = jsonString.data(using: .utf8),
              let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FaroReactNative", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid config JSON"])
        }

        let appObj = obj["app"] as? [String: Any] ?? [:]
        let app = MetaApp(
            name: appObj["name"] as? String,
            version: appObj["version"] as? String,
            environment: appObj["environment"] as? String,
            namespace: appObj["namespace"] as? String,
            release: appObj["release"] as? String,
            bundleId: appObj["bundleId"] as? String
        )

        let user: MetaUser? = (obj["user"] as? [String: Any]).flatMap { parseUserDict($0) }

        let sessionConfig: SessionConfig
        if let sessionObj = obj["sessionTracking"] as? [String: Any] {
            // JS sends milliseconds, iOS SessionConfig uses seconds
            let maxDurationMs = sessionObj["maxSessionDurationMs"] as? Double ?? (4 * 60 * 60 * 1000)
            let timeoutMs = sessionObj["sessionTimeoutMs"] as? Double ?? (15 * 60 * 1000)
            sessionConfig = SessionConfig(
                enabled: sessionObj["enabled"] as? Bool ?? true,
                persistent: sessionObj["persistent"] as? Bool ?? true,
                maxSessionDurationSeconds: maxDurationMs / 1000.0,
                sessionTimeoutSeconds: timeoutMs / 1000.0,
                samplingRate: sessionObj["samplingRate"] as? Double ?? 1.0
            )
        } else {
            sessionConfig = SessionConfig()
        }

        let batchConfig: BatchConfig
        if let batchObj = obj["batchConfig"] as? [String: Any] {
            batchConfig = BatchConfig(
                itemLimit: batchObj["itemLimit"] as? Int ?? 30,
                sendTimeoutMs: batchObj["sendTimeoutMs"] as? Int ?? 5000
            )
        } else {
            batchConfig = BatchConfig()
        }

        return FaroConfig(
            collectorUrl: obj["collectorUrl"] as? String ?? "",
            app: app,
            apiKey: obj["apiKey"] as? String,
            user: user,
            sessionTracking: sessionConfig,
            enableCrashReporting: obj["enableCrashReporting"] as? Bool ?? false,
            enableHangDetection: obj["enableHangDetection"] as? Bool ?? true,
            enableLifecycleTracking: obj["enableLifecycleTracking"] as? Bool ?? true,
            enableNetworkMonitoring: obj["enableNetworkMonitoring"] as? Bool ?? true,
            batchConfig: batchConfig,
            internalLoggerLevel: parseLoggerLevel(obj["internalLoggerLevel"] as? String),
            eventDomain: obj["eventDomain"] as? String ?? "app"
        )
    }

    private func parseUserDict(_ obj: [String: Any]) -> MetaUser? {
        return MetaUser(
            email: obj["email"] as? String,
            id: obj["id"] as? String,
            username: obj["username"] as? String,
            fullName: obj["fullName"] as? String,
            roles: obj["roles"] as? String,
            hash: obj["hash"] as? String,
            attributes: obj["attributes"] as? [String: String]
        )
    }

    private func parseLoggerLevel(_ level: String?) -> InternalLoggerLevel {
        switch level?.lowercased() {
        case "verbose": return .verbose
        case "debug": return .debug
        case "info": return .info
        case "warn": return .warn
        case "error": return .error
        case "none": return .none
        default: return .error
        }
    }

    private func parseUser(_ jsonString: String) -> MetaUser? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return MetaUser(
            email: obj["email"] as? String,
            id: obj["id"] as? String,
            username: obj["username"] as? String,
            fullName: obj["fullName"] as? String,
            roles: obj["roles"] as? String,
            hash: obj["hash"] as? String,
            attributes: obj["attributes"] as? [String: String]
        )
    }

    private func parseStringDict(_ jsonString: String) -> [String: String]? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }
        return dict
    }

    private func parseDoubleDict(_ jsonString: String) -> [String: Double] {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else {
            return [:]
        }
        return dict
    }

    private func parseStacktrace(_ jsonString: String) -> Stacktrace? {
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let framesArray = obj["frames"] as? [[String: Any]] else {
            return nil
        }

        let frames = framesArray.map { frame in
            ExceptionStackFrame(
                filename: frame["filename"] as? String ?? "unknown",
                function: frame["function"] as? String ?? "anonymous",
                colno: frame["colno"] as? Int,
                lineno: frame["lineno"] as? Int
            )
        }

        return Stacktrace(frames: frames)
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
}
