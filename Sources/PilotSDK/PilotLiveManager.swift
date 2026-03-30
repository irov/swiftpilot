import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class PilotLiveManager {
    var onLiveModeChanged: ((Bool, Int64) -> Void)?

    private let httpClient: PilotHttpClient
    private let lock = NSLock()
    private var isLive = false
    private let publisher = PilotLiveKitPublisher()

    init(httpClient: PilotHttpClient) {
        self.httpClient = httpClient
    }

    // MARK: - Public API

    func start(sessionToken: String, payload: [String: Any]?) -> [String: Any] {
        lock.lock()
        let wasLive = isLive
        lock.unlock()

        stopLiveRuntime()
        if wasLive {
            onLiveModeChanged?(false, 0)
        }

        do {
            let requested = LiveSettings.fromPayload(payload)
            let session = try fetchPublisherSession(sessionToken: sessionToken, requestedSettings: requested)
            let liveSettings = session.settings

            try publisher.start(serverUrl: session.serverUrl, participantToken: session.participantToken)

            lock.lock()
            isLive = true
            lock.unlock()

            try publisher.enableScreenShare()

            onLiveModeChanged?(true, liveSettings.actionPollIntervalMs)

            var metadata: [String: Any] = [
                "preset": liveSettings.presetName,
                "max_dimension": liveSettings.maxDimension,
                "fps": liveSettings.framesPerSecond
            ]
            if let roomName = session.roomName {
                metadata["room_name"] = roomName
            }
            if let identity = session.participantIdentity {
                metadata["participant_identity"] = identity
            }
            metadata["video_track_name"] = session.videoTrackName
            Pilot.event("live_started", category: "live", metadata: metadata)

            var ack = buildAck(ok: true, status: "live_started")
            ack["preset"] = liveSettings.presetName
            ack["max_dimension"] = liveSettings.maxDimension
            ack["fps"] = liveSettings.framesPerSecond
            ack["room_name"] = session.roomName
            ack["video_track_name"] = session.videoTrackName
            return ack

        } catch let error as PilotError {
            stopLiveRuntime()
            PilotLog.e("Failed to start LiveKit live: %@", error.message)
            Pilot.event("live_start_failed", category: "live", metadata: [
                "message": error.message,
                "http_code": error.httpCode
            ])
            return buildAck(ok: false, status: error.message)

        } catch {
            stopLiveRuntime()
            PilotLog.e("Failed to start LiveKit live: %@", error.localizedDescription)
            Pilot.event("live_start_failed", category: "live", metadata: [
                "message": error.localizedDescription
            ])
            return buildAck(ok: false, status: error.localizedDescription)
        }
    }

    func stop() -> [String: Any] {
        lock.lock()
        let wasLive = isLive
        lock.unlock()

        stopLiveRuntime()
        onLiveModeChanged?(false, 0)

        if wasLive {
            Pilot.event("live_stopped", category: "live", metadata: nil)
        }

        return buildAck(ok: true, status: wasLive ? "live_stopped" : "live_already_stopped")
    }

    func tap(_ payload: [String: Any]?) -> [String: Any] {
        lock.lock()
        let live = isLive
        lock.unlock()

        guard live else {
            return buildAck(ok: false, status: "Live is not active")
        }

        #if os(iOS)
        let normalizedX = clampD((payload?["normalized_x"] as? Double) ?? 0.5, 0, 1)
        let normalizedY = clampD((payload?["normalized_y"] as? Double) ?? 0.5, 0, 1)

        DispatchQueue.main.async { [weak self] in
            self?.performTap(normalizedX: normalizedX, normalizedY: normalizedY)
        }

        Pilot.event("live_tap", category: "live_input", metadata: [
            "normalized_x": normalizedX,
            "normalized_y": normalizedY
        ])

        return buildAck(ok: true, status: "tap_sent")
        #else
        return buildAck(ok: false, status: "Touch dispatch is only available on iOS")
        #endif
    }

    func longPress(_ payload: [String: Any]?) -> [String: Any] {
        lock.lock()
        let live = isLive
        lock.unlock()

        guard live else {
            return buildAck(ok: false, status: "Live is not active")
        }

        #if os(iOS)
        let normalizedX = clampD((payload?["normalized_x"] as? Double) ?? 0.5, 0, 1)
        let normalizedY = clampD((payload?["normalized_y"] as? Double) ?? 0.5, 0, 1)
        let durationMs = clampI((payload?["duration_ms"] as? Int) ?? 800, 250, 2000)

        DispatchQueue.main.async { [weak self] in
            self?.performLongPress(normalizedX: normalizedX, normalizedY: normalizedY,
                                   durationMs: durationMs)
        }

        Pilot.event("live_long_press", category: "live_input", metadata: [
            "normalized_x": normalizedX,
            "normalized_y": normalizedY,
            "duration_ms": durationMs
        ])

        var ack = buildAck(ok: true, status: "long_press_sent")
        ack["duration_ms"] = durationMs
        return ack
        #else
        return buildAck(ok: false, status: "Touch dispatch is only available on iOS")
        #endif
    }

    func onSessionClosed() {
        stopLiveRuntime()
    }

    func shutdown() {
        onSessionClosed()
    }

    // MARK: - Private

    private func stopLiveRuntime() {
        lock.lock()
        isLive = false
        lock.unlock()
        publisher.stop()
    }

    private func fetchPublisherSession(sessionToken: String,
                                       requestedSettings: LiveSettings) throws -> PublisherSession {
        let response = try httpClient.getLivePublisherState(sessionToken: sessionToken)
        let statusMessage = nonEmpty(response["status_message"] as? String)

        guard response["configured"] as? Bool == true else {
            throw PilotError(statusMessage ?? "LiveKit is not configured on the server")
        }

        guard response["requested"] as? Bool == true else {
            throw PilotError(statusMessage ?? "Live request is no longer active")
        }

        guard let serverUrl = nonEmpty(response["server_url"] as? String),
              let participantToken = nonEmpty(response["participant_token"] as? String),
              let videoTrackName = nonEmpty(response["video_track_name"] as? String) else {
            throw PilotError("Server returned incomplete live credentials")
        }

        let presetName = nonEmpty(response["preset"] as? String) ?? requestedSettings.presetName
        let maxDimension = clampI((response["max_dimension"] as? Int) ?? requestedSettings.maxDimension, 240, 1440)
        let fps = clampI((response["fps"] as? Int) ?? requestedSettings.framesPerSecond, 1, 6)
        let actionPollIntervalMs = Int64(clampI(
            (response["action_poll_interval_ms"] as? Int) ?? Int(requestedSettings.actionPollIntervalMs),
            200, 2000
        ))

        return PublisherSession(
            serverUrl: serverUrl,
            participantToken: participantToken,
            roomName: nonEmpty(response["room_name"] as? String),
            participantIdentity: nonEmpty(response["participant_identity"] as? String),
            videoTrackName: videoTrackName,
            settings: LiveSettings(presetName: presetName, maxDimension: maxDimension,
                                   framesPerSecond: fps, actionPollIntervalMs: actionPollIntervalMs)
        )
    }

    // MARK: - Touch Dispatch (iOS)

    #if os(iOS)
    private func performTap(normalizedX: Double, normalizedY: Double) {
        guard let window = getKeyWindow() else { return }
        let x = CGFloat(normalizedX) * window.bounds.width
        let y = CGFloat(normalizedY) * window.bounds.height
        let point = CGPoint(x: x, y: y)

        guard let hitView = window.hitTest(point, with: nil) else { return }

        if let control = findControl(from: hitView) {
            control.sendActions(for: .touchUpInside)
        }
    }

    private func performLongPress(normalizedX: Double, normalizedY: Double, durationMs: Int) {
        guard let window = getKeyWindow() else { return }
        let x = CGFloat(normalizedX) * window.bounds.width
        let y = CGFloat(normalizedY) * window.bounds.height
        let point = CGPoint(x: x, y: y)

        guard let hitView = window.hitTest(point, with: nil) else { return }

        if let control = findControl(from: hitView) {
            control.sendActions(for: .touchDown)
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(durationMs)) {
                control.sendActions(for: .touchUpInside)
            }
        }
    }

    private func findControl(from view: UIView) -> UIControl? {
        var current: UIView? = view
        while let v = current {
            if let control = v as? UIControl {
                return control
            }
            current = v.superview
        }
        return nil
    }

    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        }
    }
    #endif

    // MARK: - Helpers

    private func buildAck(ok: Bool, status: String) -> [String: Any] {
        return ["ok": ok, "status": status]
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let v = value?.trimmingCharacters(in: .whitespaces), !v.isEmpty else { return nil }
        return v
    }

    private func clampI(_ value: Int, _ lo: Int, _ hi: Int) -> Int {
        return Swift.min(Swift.max(value, lo), hi)
    }

    private func clampD(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        return Swift.min(Swift.max(value, lo), hi)
    }

    // MARK: - Internal Types

    private struct LiveSettings {
        let presetName: String
        let maxDimension: Int
        let framesPerSecond: Int
        let actionPollIntervalMs: Int64

        static func low() -> LiveSettings {
            LiveSettings(presetName: "low", maxDimension: 540, framesPerSecond: 2, actionPollIntervalMs: 500)
        }

        static func balanced() -> LiveSettings {
            LiveSettings(presetName: "balanced", maxDimension: 720, framesPerSecond: 3, actionPollIntervalMs: 400)
        }

        static func high() -> LiveSettings {
            LiveSettings(presetName: "high", maxDimension: 1080, framesPerSecond: 4, actionPollIntervalMs: 300)
        }

        static func fromPayload(_ payload: [String: Any]?) -> LiveSettings {
            guard let payload = payload else { return low() }
            let preset = payload["preset"] as? String ?? "low"
            let base: LiveSettings
            switch preset {
            case "balanced": base = balanced()
            case "high": base = high()
            default: base = low()
            }

            return LiveSettings(
                presetName: ["low", "balanced", "high"].contains(preset) ? preset : "low",
                maxDimension: clamp((payload["max_dimension"] as? Int) ?? base.maxDimension, 240, 1440),
                framesPerSecond: clamp((payload["fps"] as? Int) ?? base.framesPerSecond, 1, 6),
                actionPollIntervalMs: Int64(clamp(
                    (payload["action_poll_interval_ms"] as? Int) ?? Int(base.actionPollIntervalMs), 200, 2000))
            )
        }

        private static func clamp(_ value: Int, _ lo: Int, _ hi: Int) -> Int {
            Swift.min(Swift.max(value, lo), hi)
        }
    }

    private struct PublisherSession {
        let serverUrl: String
        let participantToken: String
        let roomName: String?
        let participantIdentity: String?
        let videoTrackName: String
        let settings: LiveSettings
    }
}
