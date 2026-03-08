import Foundation

/**
 * Captures uncaught NSExceptions and writes crash data to disk.
 * Designed to coexist with other crash reporters (e.g., Crashlytics)
 * by chaining to the previous exception handler.
 */
public final class CrashInstrumentation: Instrumentation {
    public let name = "faro-ios:instrumentation-crash"

    private weak var faro: FaroInstance?
    private static var previousExceptionHandler: (@convention(c) (NSException) -> Void)?
    private static var sharedInstance: CrashInstrumentation?

    public init() {}

    public func install(faro: FaroInstance) {
        self.faro = faro
        CrashInstrumentation.sharedInstance = self

        // Chain with existing handler (e.g., Crashlytics)
        CrashInstrumentation.previousExceptionHandler = NSGetUncaughtExceptionHandler()

        NSSetUncaughtExceptionHandler { exception in
            CrashInstrumentation.sharedInstance?.handleCrash(exception)

            // Forward to previous handler
            CrashInstrumentation.previousExceptionHandler?(exception)
        }
    }

    private func handleCrash(_ exception: NSException) {
        let frames = Thread.callStackSymbols.enumerated().map { (index, symbol) in
            ExceptionStackFrame(
                filename: "native",
                function: symbol,
                colno: nil,
                lineno: index
            )
        }

        let exceptionEvent = ExceptionEvent(
            type: exception.name.rawValue,
            value: exception.reason ?? "Unknown exception",
            timestamp: Clock.nowTimestamp(),
            stacktrace: Stacktrace(frames: frames),
            context: [
                "isFatal": "true",
                "source": "native_crash",
                "userInfo": exception.userInfo?.description ?? ""
            ]
        )

        // Write crash to disk synchronously
        faro?.writeCrashToDisk(exceptionEvent)
    }

    public func uninstall() {
        // Restore previous handler
        if let previous = CrashInstrumentation.previousExceptionHandler {
            NSSetUncaughtExceptionHandler(previous)
        } else {
            NSSetUncaughtExceptionHandler(nil)
        }
        CrashInstrumentation.sharedInstance = nil
        faro = nil
    }
}
