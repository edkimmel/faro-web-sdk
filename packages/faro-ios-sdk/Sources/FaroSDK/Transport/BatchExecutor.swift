import Foundation

public struct BatchConfig {
    public let itemLimit: Int
    public let sendTimeoutMs: Int

    public init(itemLimit: Int = 30, sendTimeoutMs: Int = 5000) {
        self.itemLimit = itemLimit
        self.sendTimeoutMs = sendTimeoutMs
    }
}

internal final class BatchExecutor {
    private let config: BatchConfig
    private let logger: InternalLogger
    private let onFlush: ([TransportItem]) -> Void
    private var buffer: [TransportItem] = []
    private let queue = DispatchQueue(label: "com.grafana.faro.batch", attributes: .concurrent)
    private var flushTimer: DispatchWorkItem?
    var isPaused: Bool = false

    init(config: BatchConfig, logger: InternalLogger, onFlush: @escaping ([TransportItem]) -> Void) {
        self.config = config
        self.logger = logger
        self.onFlush = onFlush
    }

    func add(_ item: TransportItem) {
        if isPaused {
            logger.debug("BatchExecutor is paused, dropping item")
            return
        }

        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.buffer.append(item)

            if self.buffer.count >= self.config.itemLimit {
                self.performFlush()
            } else {
                self.scheduleFlush()
            }
        }
    }

    func flush() {
        queue.async(flags: .barrier) { [weak self] in
            self?.performFlush()
        }
    }

    private func scheduleFlush() {
        flushTimer?.cancel()
        guard config.sendTimeoutMs > 0 else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.queue.async(flags: .barrier) {
                self?.performFlush()
            }
        }
        flushTimer = workItem

        let deadline: DispatchTime = .now() + .milliseconds(config.sendTimeoutMs)
        DispatchQueue.global().asyncAfter(deadline: deadline, execute: workItem)
    }

    private func performFlush() {
        guard !buffer.isEmpty else { return }

        let items = buffer
        buffer.removeAll()
        flushTimer?.cancel()

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.onFlush(items)
        }
    }

    func shutdown() {
        queue.sync(flags: .barrier) {
            performFlush()
        }
        flushTimer?.cancel()
    }
}
