// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InfometrieCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "InfometrieCore", targets: ["InfometrieCore"])],
    targets: [
        .target(name: "InfometrieCore", path: "Infometrie/Core"),
        .testTarget(name: "InfometrieCoreTests", dependencies: ["InfometrieCore"], path: "Tests/InfometrieCoreTests")
    ]
)
