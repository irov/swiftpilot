import Foundation

public enum PilotSessionStatus: String, Sendable {
    case disconnected
    case connecting
    case waitingApproval
    case active
    case authFailed
    case rejected
    case closed
    case error
}
