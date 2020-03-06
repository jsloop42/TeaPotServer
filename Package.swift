// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TeaPotServer",
    platforms: [
       .macOS(.v10_14),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.7.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.4.0"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.1.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.1.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/mongodb/mongo-swift-driver.git", from: "0.1.3"),
    ],
    targets: [
        .target(
            name: "TeaPotServer",
            dependencies: ["NIO", "NIOHTTP1", "NIOHTTP2", "NIOTLS", "NIOSSL", "NIOFoundationCompat", "NIOExtras", "NIOWebSocket", "Logging", "Metrics", "MongoSwift"]),
        .testTarget(
            name: "TeaPotServerTests",
            dependencies: ["TeaPotServer", "Logging"]),
    ]
)
