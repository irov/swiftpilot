import Foundation

public final class PilotMetricType: Hashable, Sendable {
    public let key: String
    public let unit: String
    public let aggregation: PilotMetricAggregation

    // Built-in metric types
    public static let fps = PilotMetricType(key: "fps", unit: "", aggregation: .gauge)
    public static let frameTime = PilotMetricType(key: "frame_time", unit: "ms", aggregation: .gauge)
    public static let memory = PilotMetricType(key: "memory", unit: "bytes", aggregation: .gauge)
    public static let videoMemory = PilotMetricType(key: "video_memory", unit: "bytes", aggregation: .gauge)
    public static let cpuUsage = PilotMetricType(key: "cpu_usage", unit: "%", aggregation: .gauge)
    public static let networkRx = PilotMetricType(key: "network_rx", unit: "bytes/s", aggregation: .rate)
    public static let networkTx = PilotMetricType(key: "network_tx", unit: "bytes/s", aggregation: .rate)
    public static let batteryLevel = PilotMetricType(key: "battery_level", unit: "%", aggregation: .gauge)
    public static let batteryCharging = PilotMetricType(key: "battery_charging", unit: "", aggregation: .gauge)
    public static let drawCalls = PilotMetricType(key: "draw_calls", unit: "", aggregation: .gauge)
    public static let threadCount = PilotMetricType(key: "thread_count", unit: "", aggregation: .gauge)

    private init(key: String, unit: String, aggregation: PilotMetricAggregation) {
        self.key = key
        self.unit = unit
        self.aggregation = aggregation
    }

    public static func create(_ key: String) -> PilotMetricType {
        return PilotMetricType(key: key, unit: "", aggregation: .gauge)
    }

    public static func create(_ key: String, unit: String) -> PilotMetricType {
        return PilotMetricType(key: key, unit: unit, aggregation: .gauge)
    }

    public static func create(_ key: String, unit: String, aggregation: PilotMetricAggregation) -> PilotMetricType {
        return PilotMetricType(key: key, unit: unit, aggregation: aggregation)
    }

    public static func == (lhs: PilotMetricType, rhs: PilotMetricType) -> Bool {
        return lhs.key == rhs.key
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}
