// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Mocker",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "mocker", targets: ["Mocker"]),
        .library(name: "MockerKit", targets: ["MockerKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
        .package(url: "https://github.com/apple/containerization.git", branch: "main"),
        // Local build pin (NOT for upstream). async-http-client >= 1.31.0 adopted
        // apple/swift-configuration, which uses Foundation's `Data.bytes` (a macOS 26
        // SDK / Swift 6.2 API). This box has only the CommandLineTools macOS 15.5 SDK
        // (no Xcode), where `Data` has no `.bytes`, so the whole graph fails to compile.
        // containerization pulls async-http-client `from: 1.20.1`, which floats to 1.34.0;
        // cap it below 1.31.0 (last clean release: 1.30.3) so swift-configuration drops
        // out of the dependency tree entirely. Remove once an Xcode-26 / macOS 26 SDK is
        // installed. Upstream us/mocker does not carry this (the PR is the 3 Swift files).
        .package(url: "https://github.com/swift-server/async-http-client.git", "1.20.1" ..< "1.31.0"),
    ],
    targets: [
        // Core library shared between CLI and GUI
        .target(
            name: "MockerKit",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                .product(name: "Containerization", package: "containerization"),
                .product(name: "ContainerizationOCI", package: "containerization"),
                .product(name: "ContainerizationExtras", package: "containerization"),
            ]
        ),

        // CLI executable
        .executableTarget(
            name: "Mocker",
            dependencies: [
                "MockerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // Tests
        .testTarget(
            name: "MockerKitTests",
            dependencies: ["MockerKit"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MockerTests",
            dependencies: [
                "Mocker",
                "MockerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
