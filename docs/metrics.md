# Metrics

## Configuration

```swift
let metricConfig = PilotMetricConfig()
    .setEnabled(true)
    .setSampleIntervalMs(200)    // How often collectors are polled (100–1000ms, default: 200)
    .setBufferSize(2000)         // Max buffered entries (default: 2000)
    .setBatchSize(200)           // Max entries per request (default: 200)

let config = PilotConfig.Builder(url, token)
    .setMetricConfig(metricConfig)
    .build()
```

## Built-in Metrics

When metrics are enabled, the SDK automatically collects:

| Metric | Type Key | Unit | Aggregation |
|--------|----------|------|-------------|
| Memory (RSS) | `memory` | bytes | gauge |
| Thread count | `thread_count` | — | gauge |
| Battery level | `battery_level` | % | gauge |
| Battery charging | `battery_charging` | — | gauge |

## Built-in Metric Type Constants

| Constant | Key | Unit | Aggregation |
|----------|-----|------|-------------|
| `.fps` | fps | — | gauge |
| `.frameTime` | frame_time | ms | gauge |
| `.memory` | memory | bytes | gauge |
| `.videoMemory` | video_memory | bytes | gauge |
| `.cpuUsage` | cpu_usage | % | gauge |
| `.networkRx` | network_rx | bytes/s | rate |
| `.networkTx` | network_tx | bytes/s | rate |
| `.batteryLevel` | battery_level | % | gauge |
| `.batteryCharging` | battery_charging | — | gauge |
| `.drawCalls` | draw_calls | — | gauge |
| `.threadCount` | thread_count | — | gauge |

## Custom Metric Types

```swift
let drawCalls = PilotMetricType.create("draw_calls")
let errors = PilotMetricType.create("errors", unit: "", aggregation: .counter)
let latency = PilotMetricType.create("request_latency", unit: "ms", aggregation: .gauge)
```

## Aggregation Modes

| Mode | Description | Use case |
|------|-------------|----------|
| `.gauge` | Last/average value | FPS, memory, battery |
| `.counter` | Values are summed | Request count, errors |
| `.rate` | Per-second rate | Network bytes/s |

## Manual Recording

```swift
let metrics = Pilot.getMetrics()

metrics.record(.fps, 60.0)
metrics.record(.memory, Double(processMemory))
metrics.record(.drawCalls, Double(renderer.drawCallCount))

// With explicit timestamp
metrics.record(.cpuUsage, 45.2, timestampMs: Int64(Date().timeIntervalSince1970 * 1000))
```

## Custom Collectors

Collectors are called automatically at the configured sample interval:

```swift
class GameMetrics: PilotMetricCollector {
    func collect(_ out: inout [PilotMetricEntry]) {
        out.append(PilotMetricEntry(.fps, Double(game.currentFps)))
        out.append(PilotMetricEntry(.drawCalls, Double(renderer.drawCalls)))

        let customType = PilotMetricType.create("active_particles")
        out.append(PilotMetricEntry(customType, Double(particleSystem.activeCount)))
    }
}

// Register via config
let metricConfig = PilotMetricConfig()
    .addCollector(GameMetrics())

// Or at runtime
Pilot.getMetrics().addCollector(GameMetrics())
Pilot.getMetrics().removeCollector(myCollector)
```

## Runtime Settings

```swift
let metrics = Pilot.getMetrics()
metrics.setSampleIntervalMs(500)
metrics.setBufferSize(5000)
metrics.setBatchSize(100)
```
