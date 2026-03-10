import Foundation

internal final class DiskBufferTransport: Transport {
    let name = "faro-ios:transport-disk-buffer"

    private let diskBuffer: DiskBuffer
    private let httpTransport: HttpTransport
    private let logger: InternalLogger
    private let retryInterval: TimeInterval
    private var retryTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.edkimmel.faro.diskbuffer-transport")

    init(
        diskBuffer: DiskBuffer,
        httpTransport: HttpTransport,
        logger: InternalLogger,
        retryInterval: TimeInterval = 30.0
    ) {
        self.diskBuffer = diskBuffer
        self.httpTransport = httpTransport
        self.logger = logger
        self.retryInterval = retryInterval
    }

    func start() {
        // Send pending crashes first
        sendPendingCrashes()
        // Then pending signals
        sendPendingSignals()
        // Start retry loop
        startRetryLoop()
    }

    func send(body: TransportBody) throws {
        // Write to disk first
        diskBuffer.writeSignal(body)

        // Then try to send
        queue.async { [weak self] in
            self?.sendPendingSignals()
        }
    }

    func sendCrash(_ body: TransportBody) {
        diskBuffer.writeCrash(body)
    }

    private func sendPendingCrashes() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let crashes = self.diskBuffer.readPendingCrashes()
            for crash in crashes {
                do {
                    try self.httpTransport.send(body: crash.body)
                    self.diskBuffer.deleteFile(crash)
                    self.logger.info("Sent pending crash report: \(crash.url.lastPathComponent)")
                } catch {
                    self.logger.error("Failed to send crash report, will retry", error: error)
                    break
                }
            }
        }
    }

    private func sendPendingSignals() {
        let signals = diskBuffer.readPendingSignals()
        for signal in signals {
            do {
                try httpTransport.send(body: signal.body)
                diskBuffer.deleteFile(signal)
            } catch {
                logger.debug("Failed to send signal, will retry later")
                break
            }
        }
    }

    private func startRetryLoop() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + retryInterval, repeating: retryInterval)
        timer.setEventHandler { [weak self] in
            self?.sendPendingSignals()
        }
        timer.resume()
        retryTimer = timer
    }

    func shutdown() {
        retryTimer?.cancel()
        retryTimer = nil
        httpTransport.shutdown()
    }
}
