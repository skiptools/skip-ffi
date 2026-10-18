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
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.6"),
        .package(url: "https://github.com/skiptools/skip-foundation.git", from: "1.4.3")
    ],
    targets: [
        .target(name: "SkipFFI", dependencies: [.product(name: "SkipFoundation", package: "skip-foundation")], plugins: [.plugin(name: "skipstone", package: "skip")]),
        .testTarget(name: "SkipFFITests", dependencies: ["SkipFFI", .product(name: "SkipTest", package: "skip", condition: .when(platforms: [.macOS, .linux]))], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)

// SKIP_DYNAMIC_LIBRARIES and SKIP_BRIDGE both enforce building as dynamic
// libraries; SKIP_BRIDGE additionally puts the skipstone plugin in bridge mode
let bridgeMode = (Context.environment["SKIP_BRIDGE"] ?? "0") != "0"
let forceDylib = bridgeMode || (Context.environment["SKIP_DYNAMIC_LIBRARIES"] ?? "0") != "0"

if forceDylib {
    // all library types must be dynamic to support bridging
    package.products = package.products.map({ product in
        guard let libraryProduct = product as? Product.Library else { return product }
        return .library(name: libraryProduct.name, type: .dynamic, targets: libraryProduct.targets)
    })
}
