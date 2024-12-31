// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "skip-ffi",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .macCatalyst(.v16)],
    products: [
        .library(name: "SkipFFI", targets: ["SkipFFI"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.2.16"),
        .package(url: "https://source.skip.tools/skip-foundation.git", from: "1.2.4")
    ],
    targets: [
        .target(name: "SkipFFI", dependencies: [.product(name: "SkipFoundation", package: "skip-foundation")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipFFITests", dependencies: ["SkipFFI", .product(name: "SkipTest", package: "skip")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
