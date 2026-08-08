// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JSPowerCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "JSPowerCore", targets: ["JSPowerCore"])],
    targets: [
        .target(name: "JSPowerCore", linkerSettings: [.linkedFramework("JavaScriptCore")]),
        .testTarget(name: "JSPowerCoreTests", dependencies: ["JSPowerCore"]),
    ]
)
