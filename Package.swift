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
    dependencies: [],
    targets: [
        .target(
            name: "PilotSDK",
            dependencies: [],
            path: "Sources/PilotSDK"
        )
    ]
)
