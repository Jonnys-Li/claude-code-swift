// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeCode",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "claude-code", targets: ["ClaudeCode"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.62.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeCode",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ]
        ),
        .testTarget(
            name: "ClaudeCodeTests",
            dependencies: ["ClaudeCode"]
        )
    ]
)
