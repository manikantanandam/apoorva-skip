// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaFeatureFlags",
    platforms: [
        .iOS(.v17), .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaFeatureFlags",
            targets: ["ApoorvaFeatureFlags"]
        ),
    ],
    dependencies: [
        .package(path: "../ApoorvaModels"),
        .package(url: "https://github.com/manikantanandam/ManiLogger.git", exact: "1.2.1"),
        .package(url: "https://source.skip.tools/skip-firebase.git", "0.21.0"..<"2.0.0"),
        // Tests only: the app target reaches Firebase through skip-firebase (which re-exports it on Apple platforms).
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "12.19.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaFeatureFlags",
            dependencies: [
                // Only for `AppVersion` (version-gate comparison) — the flag catalogue and sync layer
                // otherwise need nothing else from ApoorvaModels.
                .product(name: "ApoorvaModels", package: "ApoorvaModels"),
                .product(name: "ManiLogger", package: "ManiLogger"),
                .product(name: "SkipFirebaseCore", package: "skip-firebase"),
                .product(name: "SkipFirebaseRemoteConfig", package: "skip-firebase")
            ]
        ),
        .testTarget(
            name: "ApoorvaFeatureFlagsTests",
            dependencies: [
                "ApoorvaFeatureFlags",
                .product(name: "FirebaseCore", package: "firebase-ios-sdk")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
