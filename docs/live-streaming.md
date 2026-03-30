# Live Streaming

> **Note:** iOS live streaming is implemented with ReplayKit + LiveKit. If you install the SDK via CocoaPods, add all three source entries described in [ios-integration.md](ios-integration.md) so CocoaPods can resolve both `PilotSDK` and the current LiveKit pods.

## How It Works

1. Dashboard user clicks "Start Stream" → `LIVE_START` action sent to SDK
2. SDK requests screen recording permission via `ReplayKit`
3. SDK publishes video track to LiveKit room
4. Dashboard displays real-time video
5. Dashboard can send touch events (`LIVE_TAP`, `LIVE_LONG_PRESS`)
6. Dashboard user clicks "Stop Stream" → `LIVE_STOP` action sent

## Requirements

- LiveKit server (self-hosted or cloud)
- App target must include `ReplayKit` framework
- User must grant screen recording permission

## Remote Touch on iOS

On iOS, the SDK draws an in-app touch indicator overlay for remote taps and long presses and injects a synthetic touch into the active application window.

The touch goes through normal UIKit hit-testing, so regular controls, engine canvases, and in-app system overlays can intercept it through the same touch handling path they already use locally.

## Action Types

| Action | Description |
|--------|-------------|
| `.liveStart` | Start live streaming |
| `.liveStop` | Stop live streaming |
| `.liveTap` | Remote tap at coordinates |
| `.liveLongPress` | Remote long press at coordinates |

## Self-Hosting

See [self-hosting.md](self-hosting.md) for LiveKit server setup instructions.
