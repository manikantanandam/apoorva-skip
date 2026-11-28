// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaModels",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaModels",
            targets: ["ApoorvaModels"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/manikantanandam/ManiUtilities.git", exact: "1.0.0")
        // No dependency on ApoorvaFeatureFlags, even test-only: ApoorvaFeatureFlags depends on
        // ApoorvaModels (for AppVersion), so the reverse would be a circular package dependency —
        // which Xcode's plugin-context graph walker doesn't detect, it just recurses until it
        // stack-overflows (crashes Xcode outright rather than erroring). Vertical.defaultFlags and
        // its test both use raw string literals instead of the FeatureFlag enum for this reason.
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaModels",
            dependencies: [
                .product(name: "ApoorvaUtilities", package: "ManiUtilities")
            ]
        ),
        .testTarget(
            name: "ApoorvaModelsTests",
            dependencies: [
                "ApoorvaModels",
                .product(name: "ApoorvaUtilities", package: "ManiUtilities")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
