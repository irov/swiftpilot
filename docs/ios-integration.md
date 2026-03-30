# iOS Integration Guide

## Installation

### CocoaPods

```ruby
source "https://cdn.cocoapods.org/"
source "https://github.com/livekit/podspecs.git"
source "https://github.com/irov/swiftpilot-podspecs.git"

platform :ios, "13.0"

target "MyApp" do
    pod "PilotSDK", "~> 1.0"
end
```

`PilotSDK` still pulls `LiveKitClient` `2.12.1` transitively, so you do not need to add a separate `pod "LiveKitClient"` line.
All three `source` entries are required: `PilotSDK` is published in `irov/swiftpilot-podspecs`, while recent LiveKit CocoaPods specs are published in the LiveKit spec repo instead of CocoaPods trunk.

## Basic Setup

### 1. Import

```swift
import PilotSDK
```

### 2. Initialize

Initialize the SDK as early as possible (e.g., in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or your app's `@main` entry):

```swift
let config = PilotConfig.Builder("https://pilot.example.com", "plt_your_api_token")
    .setDeviceId("my-device-id")
    .setDeviceName("iPhone 15 Pro (iOS 17.2)")
    .build()

Pilot.initialize(config)
```

If `deviceId` or `deviceName` are not set, the SDK auto-detects them from `UIDevice`.

## Live Input for Custom Renderers

If your app uses a custom renderer or engine surface instead of regular UIKit controls, register a `PilotLiveInputListener` and forward remote taps into your own input system.

```swift
final class GameLiveInput: PilotLiveInputListener {
    func onPilotLiveTap(normalizedX: Double, normalizedY: Double) -> Bool {
        game.injectTap(x: normalizedX, y: normalizedY)
        return true
    }

    func onPilotLiveLongPress(normalizedX: Double, normalizedY: Double, durationMs: Int) -> Bool {
        game.injectLongPress(x: normalizedX, y: normalizedY, durationMs: durationMs)
        return true
    }
}

let config = PilotConfig.Builder(url, token)
    .setLiveInputListener(GameLiveInput())
    .build()
```

For Objective-C / Objective-C++ hosts, the bridge exposes `PilotObjCLiveInputDelegate` through `setLiveInputListener:` on `PilotConfigBuilder`.

### 3. Auto-connect vs Manual

By default `autoConnect` is `true` — the SDK connects immediately after `initialize()`.

To connect manually:

```swift
let config = PilotConfig.Builder(url, token)
    .setAutoConnect(false)
    .build()

Pilot.initialize(config)

// Later, when ready:
Pilot.connect()
```

## Session Attributes

Attach static and dynamic attributes to the session:

```swift
let attrs = PilotSessionAttributes()
    .put("app_version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
    .put("build_number", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")
    .put("install_id", installId)
    .putProvider("current_level") { gameState.currentLevel }
    .putProvider("player_coins") { gameState.coins }

let config = PilotConfig.Builder(url, token)
    .setSessionAttributes(attrs)
    .build()
```

- **Static** attributes are sent once at connect time
- **Dynamic** providers are polled on each action cycle; only changed values are sent

### Supported Attribute Value Types

- `String`
- `Int`, `Double`, `Float`
- `Bool`
- `nil` (sent as JSON `null`)

## Session Status

```swift
let status = Pilot.getStatus()
// .disconnected, .connecting, .waitingApproval, .active,
// .authFailed, .rejected, .closed, .error
```

## Session Lifecycle Listener

```swift
class MyListener: PilotSessionListener {
    func onPilotSessionConnecting() {
        print("SDK is connecting to the server")
    }

    func onPilotSessionWaitingApproval(_ requestId: String) {
        print("Waiting for dashboard approval: \(requestId)")
    }

    func onPilotSessionStarted(_ sessionToken: String) {
        print("Session is active!")
    }

    func onPilotSessionClosed() {
        print("Session closed")
    }

    func onPilotSessionRejected() {
        print("Connection rejected by dashboard user")
    }

    func onPilotSessionAuthFailed() {
        print("API token is invalid (HTTP 401)")
    }

    func onPilotSessionError(_ error: PilotError) {
        print("Error: \(error.message)")
    }
}

// Register via config
let config = PilotConfig.Builder(url, token)
    .setSessionListener(MyListener())
    .build()

// Or add/remove at runtime
Pilot.addSessionListener(listener)
Pilot.removeSessionListener(listener)
```

## Disconnect & Shutdown

```swift
// Disconnect but keep SDK alive (can reconnect later)
Pilot.disconnect()

// Full shutdown — releases all resources
// After this, initialize() can be called again
Pilot.shutdown()
```
