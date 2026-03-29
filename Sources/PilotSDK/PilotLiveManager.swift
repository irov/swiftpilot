import Foundation

final class PilotLiveManager {
    private let httpClient: PilotHttpClient
    private let updatePollInterval: (Bool, Int64) -> Void

    init(httpClient: PilotHttpClient, updatePollInterval: @escaping (Bool, Int64) -> Void) {
        self.httpClient = httpClient
        self.updatePollInterval = updatePollInterval
    }

    func start(sessionToken: String, payload: [String: Any]?) -> [String: Any] {
        // LiveKit integration placeholder — requires LiveKit Swift SDK
        return buildAck(ok: false, status: "Live streaming not available on iOS yet")
    }

    func stop() -> [String: Any] {
        updatePollInterval(false, 0)
        return buildAck(ok: true, status: "stopped")
    }

    func tap(_ payload: [String: Any]?) -> [String: Any] {
        return buildAck(ok: false, status: "Not supported")
    }

    func longPress(_ payload: [String: Any]?) -> [String: Any] {
        return buildAck(ok: false, status: "Not supported")
    }

    func onSessionClosed() {
        updatePollInterval(false, 0)
    }

    func shutdown() {}

    private func buildAck(ok: Bool, status: String) -> [String: Any] {
        return ["ok": ok, "status": status]
    }
}
