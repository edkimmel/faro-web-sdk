import Foundation

public struct LogEvent: Codable {
    public let message: String
    public let level: LogLevel
    public let timestamp: String
    public let context: [String: String]?
    public let trace: TraceContext?

    public init(
        message: String, level: LogLevel, timestamp: String,
        context: [String: String]? = nil, trace: TraceContext? = nil
    ) {
        self.message = message; self.level = level; self.timestamp = timestamp
        self.context = context; self.trace = trace
    }
}

public struct ExceptionStackFrame: Codable {
    public let filename: String
    public let function: String
    public let colno: Int?
    public let lineno: Int?

    public init(filename: String, function: String, colno: Int? = nil, lineno: Int? = nil) {
        self.filename = filename; self.function = function
        self.colno = colno; self.lineno = lineno
    }
}

public struct Stacktrace: Codable {
    public let frames: [ExceptionStackFrame]

    public init(frames: [ExceptionStackFrame]) {
        self.frames = frames
    }
}

public struct ExceptionEvent: Codable {
    public let type: String
    public let value: String
    public let timestamp: String
    public let stacktrace: Stacktrace?
    public let context: [String: String]?
    public let trace: TraceContext?

    public init(
        type: String, value: String, timestamp: String,
        stacktrace: Stacktrace? = nil, context: [String: String]? = nil,
        trace: TraceContext? = nil
    ) {
        self.type = type; self.value = value; self.timestamp = timestamp
        self.stacktrace = stacktrace; self.context = context; self.trace = trace
    }
}

public struct MeasurementEvent: Codable {
    public let type: String
    public let values: [String: Double]
    public let timestamp: String
    public let context: [String: String]?
    public let trace: TraceContext?

    public init(
        type: String, values: [String: Double], timestamp: String,
        context: [String: String]? = nil, trace: TraceContext? = nil
    ) {
        self.type = type; self.values = values; self.timestamp = timestamp
        self.context = context; self.trace = trace
    }
}

public struct EventEvent: Codable {
    public let name: String
    public let timestamp: String
    public let domain: String?
    public let attributes: [String: String]?
    public let trace: TraceContext?

    public init(
        name: String, timestamp: String, domain: String? = nil,
        attributes: [String: String]? = nil, trace: TraceContext? = nil
    ) {
        self.name = name; self.timestamp = timestamp; self.domain = domain
        self.attributes = attributes; self.trace = trace
    }
}

public struct TraceContext: Codable {
    public let trace_id: String
    public let span_id: String

    public init(trace_id: String, span_id: String) {
        self.trace_id = trace_id; self.span_id = span_id
    }
}
