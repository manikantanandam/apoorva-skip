// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaModules",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaModules",
            targets: ["ApoorvaModules"]
        ),
    ],
    dependencies: [
        .package(path: "../ApoorvaRepository"),
        .package(path: "../ApoorvaServices"),
        .package(path: "../ApoorvaModels"),
        .package(url: "https://github.com/manikantanandam/ManiUtilities.git", exact: "1.0.0"),
        .package(path: "../ApoorvaEnvironment"),
        .package(path: "../ApoorvaLogging"),
        .package(url: "https://github.com/manikantanandam/ManiSwiftUIComponents.git", exact: "1.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaModules",
            dependencies: [
                .product(name: "ApoorvaRepository", package: "ApoorvaRepository"),
                .product(name: "ApoorvaUtilities", package: "ManiUtilities"),
                .product(name: "ApoorvaEnvironment", package: "ApoorvaEnvironment"),
                .product(name: "ApoorvaLogging", package: "ApoorvaLogging"),
                .product(name: "ManiSwiftUIComponents", package: "ManiSwiftUIComponents")
            ]
        ),
        .testTarget(
            name: "ApoorvaModulesTests",
            dependencies: [
                "ApoorvaModules",
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                .product(name: "ApoorvaModels", package: "ApoorvaModels"),
                .product(name: "ApoorvaRepository", package: "ApoorvaRepository"),
                .product(name: "ApoorvaLogging", package: "ApoorvaLogging")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
