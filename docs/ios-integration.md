# iOS Integration Guide

## Installation

### Swift Package Manager (recommended)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/irov/swiftpilot.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the repository URL.

### CocoaPods

```ruby
pod 'PilotSDK', '~> 1.0'
```

`LiveKitClient` is installed automatically as a transitive dependency of `PilotSDK`.

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
