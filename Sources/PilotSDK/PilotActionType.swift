import Foundation

public enum PilotActionType: String, Sendable {
    case click = "click"
    case change = "change"
    case toggle = "toggle"
    case liveStart = "live_start"
    case liveStop = "live_stop"
    case liveTap = "live_tap"
    case liveLongPress = "live_long_press"
    case unknown = ""

    public static func from(_ value: String) -> PilotActionType {
        return PilotActionType(rawValue: value) ?? .unknown
    }
}
