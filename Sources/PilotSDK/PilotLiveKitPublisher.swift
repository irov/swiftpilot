#if canImport(LiveKit) && os(iOS)
import Foundation
import LiveKit

final class PilotLiveKitPublisher {
    private var room: Room?
    private let lock = NSLock()

    private final class ErrorBox: @unchecked Sendable {
        var value: Error?
    }

    func start(serverUrl: String, participantToken: String) throws {
        lock.lock()
        let existingRoom = room
        room = nil
        lock.unlock()

        if let existingRoom = existingRoom {
            releaseRoom(existingRoom)
        }

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
            throw error
        }

        lock.lock()
        room = newRoom
        lock.unlock()
    }

    func enableScreenShare() throws {
        lock.lock()
        let activeRoom = room
        lock.unlock()

        guard let activeRoom = activeRoom else {
            throw PilotError("Room not connected")
        }

        let errorBox = ErrorBox()
        let semaphore = DispatchSemaphore(value: 0)

        Task.detached {
            do {
                try await activeRoom.localParticipant.setScreenShare(enabled: true)
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

    func stop() {
        lock.lock()
        let activeRoom = room
        room = nil
        lock.unlock()

        if let activeRoom = activeRoom {
            releaseRoom(activeRoom)
        }
    }

    private func releaseRoom(_ targetRoom: Room) {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try? await targetRoom.localParticipant.setScreenShare(enabled: false)
            await targetRoom.disconnect()
            semaphore.signal()
        }
        semaphore.wait()
    }
}
#endif
