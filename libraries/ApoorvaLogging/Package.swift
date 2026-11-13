// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaLogging",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        .library(
            name: "ApoorvaLogging",
            targets: ["ApoorvaLogging"]
        ),
    ],
    targets: [
        .target(
            name: "ApoorvaLogging"
        ),
        .testTarget(
            name: "ApoorvaLoggingTests",
            dependencies: ["ApoorvaLogging"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
