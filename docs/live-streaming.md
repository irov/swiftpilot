# Live Streaming

> **Note:** Live streaming support for iOS is planned and requires integration with the [LiveKit Swift SDK](https://github.com/livekit/client-sdk-swift). The current SDK includes a placeholder implementation.

## How It Works (planned)

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

## Action Types

| Action | Description |
|--------|-------------|
| `.liveStart` | Start live streaming |
| `.liveStop` | Stop live streaming |
| `.liveTap` | Remote tap at coordinates |
| `.liveLongPress` | Remote long press at coordinates |

## Self-Hosting

See [self-hosting.md](self-hosting.md) for LiveKit server setup instructions.
