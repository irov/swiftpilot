import Foundation

public enum PilotMetricAggregation: String, Sendable {
    case gauge = "gauge"
    case counter = "counter"
    case rate = "rate"
}
