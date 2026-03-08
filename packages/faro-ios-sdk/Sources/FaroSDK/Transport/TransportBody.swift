import Foundation

public struct TransportBody: Codable {
    public let meta: Meta
    public let logs: [LogEvent]?
    public let exceptions: [ExceptionEvent]?
    public let measurements: [MeasurementEvent]?
    public let events: [EventEvent]?

    public init(
        meta: Meta,
        logs: [LogEvent]? = nil,
        exceptions: [ExceptionEvent]? = nil,
        measurements: [MeasurementEvent]? = nil,
        events: [EventEvent]? = nil
    ) {
        self.meta = meta
        self.logs = logs
        self.exceptions = exceptions
        self.measurements = measurements
        self.events = events
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        return JSONDecoder()
    }()

    public func toJSON() throws -> Data {
        return try Self.encoder.encode(self)
    }

    public static func fromJSON(_ data: Data) throws -> TransportBody {
        return try decoder.decode(TransportBody.self, from: data)
    }
}

public enum TransportItemType: String {
    case log
    case exception
    case measurement
    case event
}

public struct TransportItem {
    public let type: TransportItemType
    public let payload: Any
    public let meta: Meta

    public init(type: TransportItemType, payload: Any, meta: Meta) {
        self.type = type
        self.payload = payload
        self.meta = meta
    }
}
