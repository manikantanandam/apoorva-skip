// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "apoorva-skip",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Apoorva", type: .dynamic, targets: ["Apoorva"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.13"),
        .package(url: "https://github.com/skiptools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://source.skip.tools/skip-firebase.git", "0.9.0"..<"2.0.0"),
        .package(path: "./libraries/ApoorvaAppCore")
    ],
    targets: [
        .target(
            name: "Apoorva",
            dependencies: [
                .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
                .product(name: "SkipFirebaseFirestore", package: "skip-firebase"),
                .product(name: "SkipFirebaseAuth", package: "skip-firebase"),
                .product(name: "ApoorvaAppCore", package: "ApoorvaAppCore")
            ],
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "skipstone", package: "skip")
            ]
        ),
    ]
)
