import Foundation

public final class PilotMetricEntry {
    public let type: PilotMetricType
    public let value: Double
    public let timestampMs: Int64

    public init(_ type: PilotMetricType, _ value: Double) {
        self.type = type
        self.value = value
        self.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
    }

    public init(_ type: PilotMetricType, _ value: Double, timestampMs: Int64) {
        self.type = type
        self.value = value
        self.timestampMs = timestampMs
    }

    func toJson() -> [String: Any] {
        return [
            "metric_type": type.key,
            "value": value,
            "client_timestamp": timestampMs,
            "aggregation": type.aggregation.rawValue
        ]
    }
}
