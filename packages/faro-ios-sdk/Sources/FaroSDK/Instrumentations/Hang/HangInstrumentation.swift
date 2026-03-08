import Foundation

/**
 * Detects main thread hangs using a watchdog mechanism.
 * Reports when the main thread is blocked for longer than the configured threshold.
 */
public final class HangInstrumentation: Instrumentation {
    public let name = "faro-ios:instrumentation-hang"

    private weak var faro: FaroInstance?
    private var watchdogThread: Thread?
    private let threshold: TimeInterval
    private let checkInterval: TimeInterval
    private var isRunning = false

    public init(threshold: TimeInterval = 2.0, checkInterval: TimeInterval = 1.0) {
        self.threshold = threshold
        self.checkInterval = checkInterval
    }

    public func install(faro: FaroInstance) {
        self.faro = faro
        isRunning = true

        let thread = Thread { [weak self] in
            self?.watchdogLoop()
        }
        thread.name = "com.grafana.faro.hang-detector"
        thread.qualityOfService = .userInteractive
        thread.start()
        watchdogThread = thread
    }

    private func watchdogLoop() {
        while isRunning {
            var responded = false

            DispatchQueue.main.async {
                responded = true
            }

            Thread.sleep(forTimeInterval: threshold)

            if !responded && isRunning {
                reportHang()
                // Wait extra time before checking again to avoid spam
                Thread.sleep(forTimeInterval: checkInterval)
            }
        }
    }

    private func reportHang() {
        // Capture main thread stack trace
        let symbols = Thread.main.threadDictionary.description
        let frames = Thread.callStackSymbols.map { symbol in
            ExceptionStackFrame(
                filename: "native",
                function: symbol,
                colno: nil,
                lineno: nil
            )
        }

        faro?.pushError(
            type: "MainThreadHang",
            value: "Main thread blocked for more than \(threshold)s",
            stacktrace: Stacktrace(frames: frames),
            context: [
                "source": "hang_detection",
                "threshold_seconds": String(threshold)
            ]
        )
    }

    public func uninstall() {
        isRunning = false
        watchdogThread?.cancel()
        watchdogThread = nil
        faro = nil
    }
}
