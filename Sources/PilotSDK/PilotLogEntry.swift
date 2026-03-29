import Foundation

public final class PilotLogEntry {
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public let level: String
    public let message: String
    public let category: String?
    public let thread: String?
    public let metadata: [String: Any]?
    public let attributes: [String: Any]?
    public let clientTimestamp: String

    public init(level: PilotLogLevel, message: String, metadata: [String: Any]? = nil) {
        self.level = level.rawValue
        self.message = message
        self.category = nil
        self.thread = nil
        self.metadata = metadata
        self.attributes = nil
        self.clientTimestamp = PilotLogEntry.formatTimestamp(Date())
    }

    public init(level: PilotLogLevel, message: String,
                category: String?, thread: String?,
                metadata: [String: Any]?, attributes: [String: Any]? = nil) {
        self.level = level.rawValue
        self.message = message
        self.category = category
        self.thread = thread
        self.metadata = metadata
        self.attributes = attributes
        self.clientTimestamp = PilotLogEntry.formatTimestamp(Date())
    }

    public init(level: PilotLogLevel, message: String,
                category: String?, thread: String?,
                metadata: [String: Any]?, attributes: [String: Any]?,
                clientTimestamp: Date) {
        self.level = level.rawValue
        self.message = message
        self.category = category
        self.thread = thread
        self.metadata = metadata
        self.attributes = attributes
        self.clientTimestamp = PilotLogEntry.formatTimestamp(clientTimestamp)
    }

    init(levelString: String, message: String,
         category: String?, thread: String?,
         metadata: [String: Any]?, attributes: [String: Any]?,
         clientTimestampMs: Int64) {
        self.level = levelString
        self.message = message
        self.category = category
        self.thread = thread
        self.metadata = metadata
        self.attributes = attributes
        self.clientTimestamp = PilotLogEntry.formatTimestamp(Date(timeIntervalSince1970: TimeInterval(clientTimestampMs) / 1000.0))
    }

    public static func debug(_ message: String) -> PilotLogEntry {
        return PilotLogEntry(level: .debug, message: message)
    }

    public static func info(_ message: String) -> PilotLogEntry {
        return PilotLogEntry(level: .info, message: message)
    }

    public static func warning(_ message: String) -> PilotLogEntry {
        return PilotLogEntry(level: .warning, message: message)
    }

    public static func error(_ message: String) -> PilotLogEntry {
        return PilotLogEntry(level: .error, message: message)
    }

    public static func critical(_ message: String) -> PilotLogEntry {
        return PilotLogEntry(level: .critical, message: message)
    }

    private static func formatTimestamp(_ date: Date) -> String {
        return isoFormatter.string(from: date)
    }

    func toJson() -> [String: Any] {
        var json: [String: Any] = [
            "level": level,
            "message": message,
            "client_timestamp": clientTimestamp
        ]

        if let category = category {
            json["category"] = category
        }

        if let thread = thread {
            json["thread"] = thread
        }

        if let metadata = metadata, !metadata.isEmpty {
            json["metadata"] = metadata
        }

        if let attributes = attributes, !attributes.isEmpty {
            json["attributes"] = attributes
        }

        return json
    }
}
