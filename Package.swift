// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "skip-ffi",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
        .library(name: "SkipFFI", type: .dynamic, targets: ["SkipFFI"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "0.6.140"),
        .package(url: "https://source.skip.tools/skip-lib.git", from: "0.0.0")
    ],
    targets: [
        .target(name: "SkipFFI", dependencies: [.product(name: "SkipLib", package: "skip-lib")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipFFITests", dependencies: ["SkipFFI", .product(name: "SkipTest", package: "skip")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
