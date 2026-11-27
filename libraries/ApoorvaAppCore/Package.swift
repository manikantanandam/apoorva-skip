// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ApoorvaAppCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ApoorvaAppCore",
            targets: ["ApoorvaAppCore"]
        ),
    ],
    dependencies: [
        .package(path: "../ApoorvaModules"),
        .package(url: "https://github.com/manikantanandam/ManiUtilities.git", exact: "1.0.0"),
        .package(path: "../ApoorvaEnvironment"),
        .package(url: "https://github.com/manikantanandam/ManiLogger.git", exact: "1.2.1"),
        .package(path: "../ApoorvaServices"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", exact: "12.19.2"),
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.13"),
        .package(url: "https://github.com/skiptools/skip-fuse-ui.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ApoorvaAppCore",
            dependencies: [
                .product(name: "ApoorvaModules", package: "ApoorvaModules"),
                .product(name: "ApoorvaUtilities", package: "ManiUtilities"),
                .product(name: "ApoorvaEnvironment", package: "ApoorvaEnvironment"),
                .product(name: "ManiLogger", package: "ManiLogger"),
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                // Unconditional (like the app target): skipstone resolves the Kotlin side's dependencies on the
                // host, so an Android-only condition leaves the generated bridge code without `skip.bridge`.
                .product(name: "SkipFuseUI", package: "skip-fuse-ui")
            ],
            // skipstone generates the SkipUIBridging conformance custom views need to render on Android;
            // without it they render as EmptyView (see docs/decisions/android-readiness.md).
            plugins: [.plugin(name: "skipstone", package: "skip")]
        ),
        .testTarget(
            name: "ApoorvaAppCoreTests",
            dependencies: [
                "ApoorvaAppCore",
                .product(name: "ApoorvaEnvironment", package: "ApoorvaEnvironment"),
                .product(name: "ApoorvaServices", package: "ApoorvaServices"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk")
            ]
        ),

    ],
    swiftLanguageModes: [.v6]
)
