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
        thread.name = "com.edkimmel.faro.hang-detector"
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
        // Capture main thread's stack trace by dispatching to it synchronously
        // with a very short timeout. Since the main thread is hung, we fall back
        // to reporting without a stack trace rather than capturing the wrong thread.
        var mainThreadSymbols: [String]?
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            mainThreadSymbols = Thread.callStackSymbols
            sem.signal()
        }
        // Give the main thread a brief chance to respond (it's likely still hung)
        _ = sem.wait(timeout: .now() + 0.1)

        let symbols = mainThreadSymbols ?? []
        let frames = symbols.map { symbol in
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
            stacktrace: frames.isEmpty ? nil : Stacktrace(frames: frames),
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
