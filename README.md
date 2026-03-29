# Pilot SDK for iOS

Lightweight Swift SDK for connecting iOS applications to the **Pilot** remote debug dashboard.

## Features

- **Remote UI** — Declarative panel builder with widgets (buttons, switches, inputs, tables, etc.)
- **Structured Logging** — Buffered log pipeline with categories, metadata, and custom attributes
- **Metrics** — System metrics (memory, threads, battery) + custom metric collectors
- **Live Streaming** — Screen broadcast via LiveKit/WebRTC *(coming soon)*
- **Events & Revenue** — Structured event and purchase tracking

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.9+
- Xcode 15+

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/irov/swiftpilot.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → enter the repository URL.

## Quick Start

```swift
import PilotSDK

// 1. Configure
let config = PilotConfig.Builder("https://pilot.example.com", "plt_your_token")
    .setDeviceId("my-device")
    .setDeviceName("iPhone 15 (iOS 17)")
    .build()

// 2. Initialize
Pilot.initialize(config)

// 3. Build UI
let ui = Pilot.getUI()
let tab = ui.addTab("Controls")
let root = tab.vertical()

root.addButton("Restart")
    .variant("contained").color("error")
    .onClick { action in
        restartGame()
    }

root.addStat("FPS")
    .unit("fps")
    .valueProvider { String(game.fps) }

// 4. Send logs
Pilot.log(.info, "Game started")

// 5. Track events
Pilot.event("level_completed", metadata: ["level": 5, "score": 1200])

// 6. Shutdown on exit
Pilot.shutdown()
```

## Configuration

```swift
let logConfig = PilotLogConfig()
    .setEnabled(true)
    .setLogLevel(.info)
    .setAttributes(PilotLogAttributes()
        .put("app_version", "1.0.0")
        .putProvider("screen_name") { currentScreen })

let metricConfig = PilotMetricConfig()
    .setEnabled(true)
    .setSampleIntervalMs(200)

let sessionAttrs = PilotSessionAttributes()
    .put("install_id", installId)
    .putProvider("level") { currentLevel }

let config = PilotConfig.Builder("https://pilot.example.com", "plt_token")
    .setLogConfig(logConfig)
    .setMetricConfig(metricConfig)
    .setSessionAttributes(sessionAttrs)
    .setAutoConnect(true)
    .build()
```

## Widgets

| Widget | Description |
|--------|-------------|
| `PilotButton` | Button with click callback |
| `PilotLabel` | Text label with optional auto-update |
| `PilotStat` | Numeric value with label and unit |
| `PilotSwitch` | Toggle switch |
| `PilotInput` | Text input field |
| `PilotSelect` | Dropdown selection |
| `PilotTextarea` | Multi-line text input |
| `PilotTable` | Data table (read-only) |
| `PilotLogs` | Log output display |

## Session Lifecycle

```swift
class MySessionHandler: PilotSessionListener {
    func onPilotSessionConnecting() { print("Connecting...") }
    func onPilotSessionWaitingApproval(_ requestId: String) { print("Waiting approval") }
    func onPilotSessionStarted(_ token: String) { print("Session active!") }
    func onPilotSessionClosed() { print("Session closed") }
    func onPilotSessionRejected() { print("Rejected") }
    func onPilotSessionAuthFailed() { print("Auth failed") }
    func onPilotSessionError(_ error: PilotError) { print("Error: \(error.message)") }
}

Pilot.addSessionListener(MySessionHandler())
```

## Metrics

Built-in metrics collected automatically:
- Memory (RSS)
- Thread count
- Battery level & charging state

Add custom collectors:

```swift
class GameMetrics: PilotMetricCollector {
    func collect(_ out: inout [PilotMetricEntry]) {
        out.append(PilotMetricEntry(.fps, Double(game.fps)))
        out.append(PilotMetricEntry(.drawCalls, Double(renderer.drawCalls)))
    }
}

Pilot.getMetrics().addCollector(GameMetrics())
```

## License

See [LICENSE](../LICENSE) for details.
