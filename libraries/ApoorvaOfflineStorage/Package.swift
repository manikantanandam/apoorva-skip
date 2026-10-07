// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaOfflineStorage",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaOfflineStorage",
            targets: ["ApoorvaOfflineStorage"]
        ),
    ],
    dependencies: [
        .package(path: "../ApoorvaModels"),
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaOfflineStorage",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "ApoorvaModels", package: "ApoorvaModels"),
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)

