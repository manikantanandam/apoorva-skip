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
        .package(path: "../ApoorvaUtilities"),
        .package(path: "../../../../Libraries/ManiSwiftUIComponents")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaModules",
            dependencies: [
                .product(name: "ApoorvaRepository", package: "ApoorvaRepository"),
                .product(name: "ApoorvaUtilities", package: "ApoorvaUtilities"),
                .product(name: "ManiSwiftUIComponents", package: "ManiSwiftUIComponents")
            ]
        ),
        .testTarget(
            name: "ApoorvaModulesTests",
            dependencies: [
                "ApoorvaModules",
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                .product(name: "ApoorvaModels", package: "ApoorvaModels")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
