import Foundation

public protocol PilotLiveInputListener: AnyObject {
    func onPilotLiveTap(normalizedX: Double, normalizedY: Double) -> Bool
    func onPilotLiveLongPress(normalizedX: Double, normalizedY: Double, durationMs: Int) -> Bool
}