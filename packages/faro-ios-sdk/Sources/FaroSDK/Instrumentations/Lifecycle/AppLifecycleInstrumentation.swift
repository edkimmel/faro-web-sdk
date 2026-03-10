import Foundation
import UIKit

public final class AppLifecycleInstrumentation: Instrumentation {
    public let name = "faro-ios:instrumentation-lifecycle"

    private weak var faro: FaroInstance?
    private var observers: [NSObjectProtocol] = []
    private let appStartTime = ProcessInfo.processInfo.systemUptime

    public init() {}

    public func install(faro: FaroInstance) {
        self.faro = faro

        // Report app start time
        let startDuration = ProcessInfo.processInfo.systemUptime - appStartTime
        faro.pushMeasurement(
            type: "app_startup",
            values: ["duration_ms": startDuration * 1000]
        )

        faro.pushEvent("app_start", domain: "app")

        // Track foreground/background transitions
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.faro?.pushEvent("app_foreground", domain: "app")
        }
        observers.append(foregroundObserver)

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.faro?.pushEvent("app_background", domain: "app")
        }
        observers.append(backgroundObserver)

        let terminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.faro?.pushEvent("app_terminate", domain: "app")
            self?.faro?.flushSynchronously()
        }
        observers.append(terminateObserver)
    }

    public func uninstall() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        faro = nil
    }
}
