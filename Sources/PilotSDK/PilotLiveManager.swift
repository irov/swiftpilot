import Foundation

final class PilotLiveManager {
    private let httpClient: PilotHttpClient

    init(httpClient: PilotHttpClient) {
        self.httpClient = httpClient
    }

    func start(sessionToken: String, payload: [String: Any]?) -> [String: Any] {
        // LiveKit integration placeholder — requires LiveKit Swift SDK
        return buildAck(ok: false, status: "Live streaming not available on iOS yet")
    }

    func stop() -> [String: Any] {
        return buildAck(ok: true, status: "stopped")
    }

    func tap(_ payload: [String: Any]?) -> [String: Any] {
        return buildAck(ok: false, status: "Not supported")
    }

    func longPress(_ payload: [String: Any]?) -> [String: Any] {
        return buildAck(ok: false, status: "Not supported")
    }

    func onSessionClosed() {
    }

    func shutdown() {}

    private func buildAck(ok: Bool, status: String) -> [String: Any] {
        return ["ok": ok, "status": status]
    }
}
