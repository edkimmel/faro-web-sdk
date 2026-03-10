import Foundation

public struct BatchConfig {
    public let itemLimit: Int
    public let sendTimeoutMs: Int
    public let maxBufferSize: Int

    public init(itemLimit: Int = 30, sendTimeoutMs: Int = 5000, maxBufferSize: Int = 1000) {
        self.itemLimit = itemLimit
        self.sendTimeoutMs = sendTimeoutMs
        self.maxBufferSize = maxBufferSize
    }
}

internal final class BatchExecutor {
    private let config: BatchConfig
    private let logger: InternalLogger
    private let onFlush: ([TransportItem]) -> Void
    private var buffer: [TransportItem] = []
    private let queue = DispatchQueue(label: "com.edkimmel.faro.batch", attributes: .concurrent)
    private var flushTimer: DispatchWorkItem?
    private var _isPaused: Bool = false
    var isPaused: Bool {
        get { queue.sync { _isPaused } }
        set { queue.async(flags: .barrier) { [weak self] in self?._isPaused = newValue } }
    }

    init(config: BatchConfig, logger: InternalLogger, onFlush: @escaping ([TransportItem]) -> Void) {
        self.config = config
        self.logger = logger
        self.onFlush = onFlush
    }

    func add(_ item: TransportItem) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self._isPaused {
                self.logger.debug("BatchExecutor is paused, dropping item")
                return
            }
            if self.buffer.count >= self.config.maxBufferSize {
                self.logger.warn("BatchExecutor buffer full (\(self.config.maxBufferSize)), dropping oldest items")
                self.buffer.removeFirst(self.buffer.count - self.config.maxBufferSize + 1)
            }

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
