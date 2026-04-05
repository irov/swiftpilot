import Foundation
import LiveKitClient
#if os(iOS)
import Combine
#endif

final class PilotLiveKitPublisher {
    private var room: Room?
    private var screenShareTrack: LocalVideoTrack?
    private var screenSharePublication: LocalTrackPublication?
    private var currentQuality = LiveQuality.default()
    private let lock = NSLock()

#if os(iOS)
    private var broadcastObserver: AnyCancellable?
    private var previousBroadcastAutoPublish = true
#endif

    private final class ErrorBox: @unchecked Sendable {
        var value: Error?
    }

    private final class BoolBox: @unchecked Sendable {
        var value = false
    }

    func start(
        serverUrl: String,
        participantToken: String,
        presetName: String,
        maxDimension: Int,
        framesPerSecond: Int
    ) throws {
        let initialQuality = LiveQuality(
            presetName: presetName,
            maxDimension: maxDimension,
            framesPerSecond: framesPerSecond
        )

        lock.lock()
        let existingRoom = room
        room = nil
        screenShareTrack = nil
        screenSharePublication = nil
        currentQuality = initialQuality
        lock.unlock()

        if let existingRoom = existingRoom {
            releaseRoom(existingRoom)
        }

#if os(iOS)
        previousBroadcastAutoPublish = BroadcastManager.shared.shouldPublishTrack
        BroadcastManager.shared.shouldPublishTrack = false
#endif

        let newRoom = Room()
        let errorBox = ErrorBox()
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached {
            do {
                try await newRoom.connect(url: serverUrl, token: participantToken)
            } catch {
                errorBox.value = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let error = errorBox.value {
            releaseRoom(newRoom)
#if os(iOS)
            BroadcastManager.shared.shouldPublishTrack = previousBroadcastAutoPublish
#endif
            throw error
        }

        lock.lock()
        room = newRoom
        currentQuality = initialQuality
        lock.unlock()

#if os(iOS)
        observeBroadcastState()
#endif
    }

    func enableScreenShare() throws {
        lock.lock()
        let activeRoom = room
        let quality = currentQuality
        lock.unlock()

        guard let activeRoom = activeRoom else {
            throw PilotError("Room not connected")
        }

        let errorBox = ErrorBox()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                _ = try await self.publishScreenShareIfPossible(
                    on: activeRoom,
                    quality: quality,
                    requestActivation: true
                )
            } catch {
                errorBox.value = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let error = errorBox.value {
            throw error
        }
    }

    func updateQuality(
        presetName: String,
        maxDimension: Int,
        framesPerSecond: Int
    ) throws -> Bool {
        lock.lock()
        let activeRoom = room
        let previousQuality = currentQuality
        let nextQuality = LiveQuality(
            presetName: presetName,
            maxDimension: maxDimension,
            framesPerSecond: framesPerSecond
        )
        lock.unlock()

        guard let activeRoom = activeRoom else {
            throw PilotError("Room not connected")
        }

        let errorBox = ErrorBox()
        let resultBox = BoolBox()
        let semaphore = DispatchSemaphore(value: 0)

        Task {
            do {
                let wasPublished = self.isScreenSharePublished(on: activeRoom)

                if wasPublished {
                    resultBox.value = try await self.replaceScreenShareTrack(on: activeRoom, quality: nextQuality)
                } else {
                    resultBox.value = try await self.publishScreenShareIfPossible(
                        on: activeRoom,
                        quality: nextQuality,
                        requestActivation: false
                    )
                }
            } catch {
                errorBox.value = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let error = errorBox.value {
            lock.lock()
            currentQuality = previousQuality
            lock.unlock()
            throw error
        }

        lock.lock()
        currentQuality = nextQuality
        lock.unlock()

        return resultBox.value
    }

    func stop() {
        lock.lock()
        let activeRoom = room
        room = nil
        screenShareTrack = nil
        screenSharePublication = nil
        currentQuality = LiveQuality.default()
        lock.unlock()

#if os(iOS)
        broadcastObserver = nil
        BroadcastManager.shared.shouldPublishTrack = previousBroadcastAutoPublish
#endif

        if let activeRoom = activeRoom {
            releaseRoom(activeRoom)
        }
    }

    private func releaseRoom(_ targetRoom: Room) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            try? await self.unpublishScreenShareIfNeeded(on: targetRoom)

#if os(iOS)
            if BroadcastManager.shared.isBroadcasting {
                BroadcastManager.shared.requestStop()
            }
#endif

            await targetRoom.disconnect()
            semaphore.signal()
        }
        semaphore.wait()
    }

    private func isScreenSharePublished(on activeRoom: Room) -> Bool {
        if let track = screenShareTrack, track.publishState == .published {
            return true
        }

        return activeRoom.localParticipant.isScreenShareEnabled()
    }

    private func publishScreenShareIfPossible(
        on activeRoom: Room,
        quality: LiveQuality,
        requestActivation: Bool
    ) async throws -> Bool {
#if os(iOS)
        if shouldUseBroadcastCapture(), !BroadcastManager.shared.isBroadcasting {
            clearScreenShareState()
            if requestActivation {
                BroadcastManager.shared.requestActivation()
            }
            return false
        }
#endif

        if isScreenSharePublished(on: activeRoom) {
            return true
        }

        let track = try await createScreenShareTrack(quality: quality)
        let publication = try await activeRoom.localParticipant.publish(
            videoTrack: track,
            options: createPublishOptions(quality: quality)
        )

        lock.lock()
        screenShareTrack = track
        screenSharePublication = publication
        currentQuality = quality
        lock.unlock()

        return true
    }

    private func replaceScreenShareTrack(on activeRoom: Room, quality: LiveQuality) async throws -> Bool {
        try await unpublishScreenShareIfNeeded(on: activeRoom)
        return try await publishScreenShareIfPossible(on: activeRoom, quality: quality, requestActivation: false)
    }

    private func unpublishScreenShareIfNeeded(on activeRoom: Room) async throws {
        let publication: LocalTrackPublication? = {
            if let current = screenSharePublication {
                return current
            }
            return activeRoom.localParticipant.localVideoTracks.first { $0.source == .screenShareVideo }
        }()

        guard let publication = publication else {
            clearScreenShareState()
            return
        }

        do {
            try await activeRoom.localParticipant.unpublish(publication: publication)
        } catch {
            clearScreenShareState()
            throw error
        }

        clearScreenShareState()
    }

    private func clearScreenShareState() {
        lock.lock()
        screenShareTrack = nil
        screenSharePublication = nil
        lock.unlock()
    }

    private func createScreenShareTrack(quality: LiveQuality) async throws -> LocalVideoTrack {
        let options = createCaptureOptions(quality: quality)

#if os(iOS)
        if shouldUseBroadcastCapture() {
            return LocalVideoTrack.createBroadcastScreenCapturerTrack(options: options)
        }

        if #available(iOS 11.0, *) {
            return LocalVideoTrack.createInAppScreenShareTrack(options: options)
        }

        throw PilotError("In-app screen capture requires iOS 11.0 or newer")
#elseif os(macOS)
        if #available(macOS 12.3, *) {
            let source = try await MacOSScreenCapturer.mainDisplaySource()
            return LocalVideoTrack.createMacOSScreenShareTrack(source: source, options: options)
        }

        throw PilotError("Screen capture requires macOS 12.3 or newer")
#else
        throw PilotError("Screen sharing is not supported on this platform")
#endif
    }

    private func createCaptureOptions(quality: LiveQuality) -> ScreenShareCaptureOptions {
        ScreenShareCaptureOptions(
            dimensions: resolveCaptureDimensions(maxDimension: quality.maxDimension),
            fps: quality.framesPerSecond,
            showCursor: true,
            appAudio: false,
            useBroadcastExtension: shouldUseBroadcastCapture(),
            includeCurrentApplication: false,
            excludeWindowIDs: []
        )
    }

    private func createPublishOptions(quality: LiveQuality) -> VideoPublishOptions {
        VideoPublishOptions(
            screenShareEncoding: VideoEncoding(
                maxBitrate: resolveMaxBitrate(for: quality),
                maxFps: quality.framesPerSecond
            ),
            simulcast: false
        )
    }

    private func resolveCaptureDimensions(maxDimension: Int) -> Dimensions {
        let safeMax = max(maxDimension, 1)
        let height = max(Int((Double(safeMax) * 9.0 / 16.0).rounded()), 1)
        return Dimensions(width: Int32(safeMax), height: Int32(height))
    }

    private func resolveMaxBitrate(for quality: LiveQuality) -> Int {
        switch quality.presetName.lowercased() {
        case "low":
            return 300_000
        case "balanced":
            return 600_000
        case "high":
            return 1_200_000
        default:
            return min(max(quality.maxDimension * quality.framesPerSecond * 278, 180_000), 2_500_000)
        }
    }

    private func shouldUseBroadcastCapture() -> Bool {
#if os(iOS)
        return ScreenShareCaptureOptions.defaultToBroadcastExtension
#else
        return false
#endif
    }

#if os(iOS)
    private func observeBroadcastState() {
        broadcastObserver = BroadcastManager.shared.isBroadcastingPublisher.sink { [weak self] isBroadcasting in
            guard let self = self else { return }

            if !isBroadcasting {
                self.clearScreenShareState()
                return
            }

            self.publishPendingBroadcastTrackIfNeeded()
        }
    }

    private func publishPendingBroadcastTrackIfNeeded() {
        lock.lock()
        let activeRoom = room
        let quality = currentQuality
        let isPublished = screenShareTrack?.publishState == .published
        lock.unlock()

        guard let activeRoom = activeRoom, !isPublished else {
            return
        }

        Task {
            _ = try? await self.publishScreenShareIfPossible(
                on: activeRoom,
                quality: quality,
                requestActivation: false
            )
        }
    }
#endif

    private struct LiveQuality {
        let presetName: String
        let maxDimension: Int
        let framesPerSecond: Int

        static func `default`() -> LiveQuality {
            LiveQuality(presetName: "low", maxDimension: 540, framesPerSecond: 2)
        }
    }
}
