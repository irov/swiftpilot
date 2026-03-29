import Foundation

public protocol PilotSessionListener: AnyObject {
    func onPilotSessionConnecting()
    func onPilotSessionWaitingApproval(_ requestId: String)
    func onPilotSessionStarted(_ sessionToken: String)
    func onPilotSessionClosed()
    func onPilotSessionRejected()
    func onPilotSessionAuthFailed()
    func onPilotSessionError(_ error: PilotError)
}

public extension PilotSessionListener {
    func onPilotSessionConnecting() {}
    func onPilotSessionWaitingApproval(_ requestId: String) {}
    func onPilotSessionStarted(_ sessionToken: String) {}
    func onPilotSessionClosed() {}
    func onPilotSessionRejected() {}
    func onPilotSessionAuthFailed() {}
    func onPilotSessionError(_ error: PilotError) {}
}
