// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-gelf",
    products: [
        .library(
            name: "GELF",
            targets: ["GELF"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.8.0"),
    ],
    targets: [
        .target(
            name: "GELF",
            dependencies: ["NIO"]),
        .testTarget(
            name: "GELFTests",
            dependencies: ["GELF", "NIOFoundationCompat"]),
        // A small executable to demonstrate how to use the library
        .target(
            name: "Sample",
            dependencies: ["GELF"]),
    ]
)
