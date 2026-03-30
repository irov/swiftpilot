// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PilotSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PilotSDK",
            targets: ["PilotSDK"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/livekit/client-sdk-swift.git", from: "2.0.18"),
    ],
    targets: [
        .target(
            name: "PilotSDK",
            dependencies: [
                .product(name: "LiveKit", package: "client-sdk-swift"),
            ],
            path: "Sources/PilotSDK"
        )
    ]
)
