import Foundation

internal enum HttpTransportError: Error {
    case invalidCollectorUrl(String)
}

internal final class HttpTransport: Transport {
    let name = "faro-ios:transport-http"

    private let collectorUrl: URL
    private let apiKey: String?
    private let logger: InternalLogger
    private let session: URLSession
    private var disabledUntil: Date = .distantPast

    private static let tooManyRequests = 429
    private static let accepted = 202
    private static let defaultRateLimitBackoffSeconds: TimeInterval = 5.0

    init(collectorUrl: String, apiKey: String?, logger: InternalLogger) throws {
        guard let url = URL(string: collectorUrl) else {
            throw HttpTransportError.invalidCollectorUrl(collectorUrl)
        }
        self.collectorUrl = url
        self.apiKey = apiKey
        self.logger = logger

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }

    func send(body: TransportBody) throws {
        if Date() < disabledUntil {
            logger.warn("Transport rate limited, dropping payload until \(disabledUntil)")
            return
        }

        let jsonData = try body.toJSON()

        var request = URLRequest(url: collectorUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        if let sessionId = body.meta.session?.id {
            request.setValue(sessionId, forHTTPHeaderField: "x-faro-session-id")
        }

        request.httpBody = jsonData

        let semaphore = DispatchSemaphore(value: 0)
        var transportError: Error?

        let task = session.dataTask(with: request) { [weak self] _, response, error in
            defer { semaphore.signal() }

            if let error = error {
                self?.logger.error("Failed to send payload", error: error)
                transportError = error
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else { return }

            switch httpResponse.statusCode {
            case Self.accepted:
                self?.logger.debug("Payload sent successfully")
            case Self.tooManyRequests:
                let backoff = self?.parseRetryAfter(httpResponse) ?? Self.defaultRateLimitBackoffSeconds
                self?.disabledUntil = Date().addingTimeInterval(backoff)
                self?.logger.warn("Rate limited, backing off for \(backoff)s")
            default:
                self?.logger.error("Unexpected response code: \(httpResponse.statusCode)")
            }
        }
        task.resume()
        semaphore.wait()

        if let error = transportError {
            throw error
        }
    }

    func shutdown() {
        session.invalidateAndCancel()
    }

    private func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval {
        guard let retryAfter = response.value(forHTTPHeaderField: "Retry-After") else {
            return Self.defaultRateLimitBackoffSeconds
        }

        if let seconds = Double(retryAfter) {
            return seconds
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let date = formatter.date(from: retryAfter) {
            return max(0, date.timeIntervalSinceNow)
        }

        return Self.defaultRateLimitBackoffSeconds
    }
}
