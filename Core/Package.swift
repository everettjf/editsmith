// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditSmithCore",
    platforms: [.macOS(.v15)],
    products: [.library(name: "EditSmithCore", targets: ["EditSmithCore"])],
    targets: [
        .target(name: "EditSmithCore", linkerSettings: [.linkedFramework("JavaScriptCore")]),
        .testTarget(name: "EditSmithCoreTests", dependencies: ["EditSmithCore"]),
    ]
)
