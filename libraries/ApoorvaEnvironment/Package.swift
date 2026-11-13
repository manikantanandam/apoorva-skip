// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaEnvironment",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaEnvironment",
            targets: ["ApoorvaEnvironment"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/manikantanandam/ManiLogger.git", exact: "1.1.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaEnvironment",
            dependencies: [
                .product(name: "ManiLogger", package: "ManiLogger")
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "ApoorvaEnvironmentTests",
            dependencies: ["ApoorvaEnvironment"]
        ),

    ]
)
