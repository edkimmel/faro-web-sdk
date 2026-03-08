import Foundation

/**
 * Monitors URLSession HTTP requests and reports them as measurements.
 *
 * Usage with URLProtocol-based monitoring:
 * ```swift
 * let instrumentation = URLSessionInstrumentation()
 * instrumentation.install(faro: faro)
 *
 * // Register the URL protocol for monitoring
 * let config = URLSessionConfiguration.default
 * config.protocolClasses = [FaroURLProtocol.self] + (config.protocolClasses ?? [])
 * let session = URLSession(configuration: config)
 * ```
 */
public final class URLSessionInstrumentation: Instrumentation {
    public let name = "faro-ios:instrumentation-network"

    private weak var faro: FaroInstance?
    static weak var sharedFaro: FaroInstance?

    public init() {}

    public func install(faro: FaroInstance) {
        self.faro = faro
        URLSessionInstrumentation.sharedFaro = faro
    }

    public func uninstall() {
        URLSessionInstrumentation.sharedFaro = nil
        faro = nil
    }

    internal static func reportRequest(
        url: String,
        method: String,
        statusCode: Int?,
        durationMs: Double,
        requestSize: Int64?,
        responseSize: Int64?,
        error: Error?
    ) {
        guard let faro = sharedFaro else { return }

        // Don't track collector URL
        if faro.shouldIgnoreUrl(url) { return }

        var values: [String: Double] = [
            "duration_ms": durationMs
        ]

        if let statusCode = statusCode {
            values["status_code"] = Double(statusCode)
        }
        if let responseSize = responseSize {
            values["response_size"] = Double(responseSize)
        }

        var context: [String: String] = [
            "url": url,
            "method": method
        ]

        if let statusCode = statusCode {
            context["status_code"] = String(statusCode)
        }
        if let error = error {
            context["error"] = error.localizedDescription
        }

        faro.pushMeasurement(
            type: "http_request",
            values: values,
            context: context
        )
    }
}

/// URLProtocol subclass for monitoring HTTP requests.
/// Register this in your URLSessionConfiguration to enable monitoring.
public final class FaroURLProtocol: URLProtocol {
    private var startTime: Date?
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()

    private static let handledKey = "com.grafana.faro.handled"

    override public class func canInit(with request: URLRequest) -> Bool {
        // Avoid infinite loops
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override public func startLoading() {
        startTime = Date()

        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: FaroURLProtocol.handledKey, in: mutableRequest)

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override public func stopLoading() {
        dataTask?.cancel()
    }
}

extension FaroURLProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        client?.urlProtocol(self, didLoad: data)
        receivedData.append(data)
    }

    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let durationMs = (startTime.map { Date().timeIntervalSince($0) } ?? 0) * 1000
        let httpResponse = task.response as? HTTPURLResponse

        URLSessionInstrumentation.reportRequest(
            url: task.originalRequest?.url?.absoluteString ?? "unknown",
            method: task.originalRequest?.httpMethod ?? "GET",
            statusCode: httpResponse?.statusCode,
            durationMs: durationMs,
            requestSize: task.originalRequest?.httpBody.map { Int64($0.count) },
            responseSize: Int64(receivedData.count),
            error: error
        )

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
