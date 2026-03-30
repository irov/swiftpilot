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

On iOS, the SDK draws an in-app touch indicator overlay for remote taps and long presses.

If your app uses regular UIKit controls, the SDK can still fall back to `UIControl` actions.
If your app renders into a custom surface or engine view, register a live input listener and inject the touch into your own input pipeline.

Swift:

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

Objective-C bridge:

```objective-c
[config setLiveInputListener:self];

- (BOOL)onPilotLiveTap:(double)normalizedX normalizedY:(double)normalizedY {
	return YES;
}

- (BOOL)onPilotLiveLongPress:(double)normalizedX normalizedY:(double)normalizedY durationMs:(NSInteger)durationMs {
	return YES;
}
```

Return `YES` / `true` when your app handled the remote touch itself. In that case the SDK skips the UIKit `UIControl` fallback.

## Action Types

| Action | Description |
|--------|-------------|
| `.liveStart` | Start live streaming |
| `.liveStop` | Stop live streaming |
| `.liveTap` | Remote tap at coordinates |
| `.liveLongPress` | Remote long press at coordinates |

## Self-Hosting

See [self-hosting.md](self-hosting.md) for LiveKit server setup instructions.
