// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EstoServer",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "EstoServer",
            dependencies: ["NIO", "NIOHTTP1", "NIOHTTP2", "NIOTLS", "NIOSSL", "NIOFoundationCompat", "NIOWebSocket", "Logging", "Metrics"]),
        .testTarget(
            name: "EstoServerTests",
            dependencies: ["EstoServer"]),
    ]
)
