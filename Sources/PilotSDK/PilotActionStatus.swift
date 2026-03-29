import Foundation

public enum PilotActionStatus: String, Sendable {
    case pending = "pending"
    case delivered = "delivered"
    case acknowledged = "acknowledged"
    case unknown = ""

    public static func from(_ value: String) -> PilotActionStatus {
        return PilotActionStatus(rawValue: value) ?? .unknown
    }
}
