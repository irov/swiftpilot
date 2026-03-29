# Logging

## Configuration

```swift
let logConfig = PilotLogConfig()
    .setEnabled(true)
    .setLogLevel(.info)        // Minimum level (default: .info)
    .setBatchSize(100)         // Max logs per request (default: 100)
    .setBufferSize(1000)       // Max buffered logs (default: 1000)

let config = PilotConfig.Builder(url, token)
    .setLogConfig(logConfig)
    .build()
```

## Basic Logging

```swift
Pilot.log(.debug, "Debug message")
Pilot.log(.info, "Player joined the game")
Pilot.log(.warning, "Low memory warning")
Pilot.log(.error, "Failed to load asset")
Pilot.log(.critical, "Unrecoverable error")
```

## Logging with Category and Thread

```swift
Pilot.log(.info, "Texture loaded", category: "assets", thread: "render")
```

## Logging with Metadata

```swift
Pilot.log(.info, "Item purchased", metadata: [
    "item_id": "sword_01",
    "price": 100,
    "currency": "gold"
])

Pilot.log(.error, "Network request failed",
          category: "network", thread: "bg",
          metadata: ["url": "/api/save", "status_code": 500])
```

## Pre-built Log Entries

```swift
let entry = PilotLogEntry(
    level: .info,
    message: "Custom log entry",
    category: "game",
    thread: Thread.current.name,
    metadata: ["key": "value"]
)
Pilot.log(entry)

// Convenience constructors
Pilot.log(PilotLogEntry.debug("Debug"))
Pilot.log(PilotLogEntry.info("Info"))
Pilot.log(PilotLogEntry.warning("Warning"))
Pilot.log(PilotLogEntry.error("Error"))
Pilot.log(PilotLogEntry.critical("Critical"))
```

## Log Attributes

Attach static and dynamic attributes to every log entry:

```swift
let logAttrs = PilotLogAttributes()
    .put("app_version", "1.2.3")
    .put("platform", "iOS")
    .putProvider("screen_name") { currentScreen }
    .putProvider("user_id") { currentUserId }

let logConfig = PilotLogConfig()
    .setAttributes(logAttrs)
```

- **Static** attributes are set once
- **Dynamic** providers are resolved at each `log()` call

## Events

Structured event entries with automatic categorization:

```swift
Pilot.event("level_completed")

Pilot.event("level_completed", metadata: [
    "level": 5,
    "score": 12000,
    "time_seconds": 45
])

Pilot.event("boss_defeated",
            category: "combat",
            metadata: ["boss_name": "Dragon"])
```

## Revenue Events

```swift
Pilot.revenue("subscription_purchased")

Pilot.revenue("iap_completed", metadata: [
    "product_id": "remove_ads",
    "price": 4.99
])
```

## Screen Tracking

```swift
Pilot.changeScreen(screenType: "game", screenName: "Level 5")
Pilot.changeScreen(screenType: "menu", screenName: "Main Menu")
Pilot.changeScreen(screenType: "shop", screenName: "Item Shop")
```

## In-App Products

```swift
// Publish product catalog
Pilot.setInAppProducts([
    ["product_id": "remove_ads", "price": "$4.99", "title": "Remove Ads"],
    ["product_id": "coin_pack", "price": "$1.99", "title": "100 Coins"]
])

// Track owned products
Pilot.setOwnedInAppProducts(["remove_ads"])

// Record a purchase
Pilot.purchaseInApp(
    transactionId: "TXN_12345",
    productIds: ["coin_pack"],
    metadata: ["source": "shop_screen"]
)
```

## SDK Internal Logging

Intercept SDK's own diagnostic logs:

```swift
class MyLogHandler: PilotLoggerListener {
    func onPilotLoggerMessage(_ level: PilotLogLevel, tag: String, message: String, error: Error?) {
        print("[\(tag)] \(level.rawValue): \(message)")
    }
}

let config = PilotConfig.Builder(url, token)
    .setLoggerListener(MyLogHandler())
    .build()
```
