// swift-tools-version:5.9
// NoiseCore: everything that is not UI. Shared by the iPhone, iPad and Mac app.
// Pure-Swift parts (models, scheduling, DSP, control protocol) build and test on Linux too,
// which is how the cloud session verifies them. Apple-only parts are fenced with
// `#if canImport(AVFoundation)` etc. and only compile on Apple platforms.
import PackageDescription

let package = Package(
    name: "NoiseCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NoiseCore", targets: ["NoiseCore"]),
    ],
    targets: [
        .target(
            name: "NoiseCore"
        ),
        .testTarget(
            name: "NoiseCoreTests",
            dependencies: ["NoiseCore"]
        ),
    ]
)
