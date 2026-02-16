// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TrackpadRelay",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "trackpad-relay", targets: ["TrackpadRelay"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "TrackpadRelay",
            dependencies: [
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "TrackpadRelayTests",
            dependencies: ["TrackpadRelay"]
        ),
    ]
)
