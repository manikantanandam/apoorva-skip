// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaRepository",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaRepository",
            targets: ["ApoorvaRepository"]
        ),
    ],
    dependencies: [
        .package(path: "../ApoorvaOfflineStorage"),
        .package(path: "../ApoorvaServices"),
        .package(path: "../ApoorvaModels"),
        .package(url: "https://github.com/manikantanandam/ManiLogger.git", exact: "1.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaRepository",
            dependencies: [
                .product(name: "ApoorvaOfflineStorage", package: "ApoorvaOfflineStorage"),
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                .product(name: "ManiLogger", package: "ManiLogger")
            ]
        ),
        .testTarget(
            name: "ApoorvaRepositoryTests",
            dependencies: [
                "ApoorvaRepository",
                .product(name: "ApoorvaOfflineStorage", package: "ApoorvaOfflineStorage"),
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                .product(name: "ApoorvaModels", package: "ApoorvaModels")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
