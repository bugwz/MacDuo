// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacDuo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacDuo", targets: ["MacDuo"])],
    targets: [
        .target(name: "FoldCore"),
        .target(name: "TouchBarBridge", publicHeadersPath: "include", linkerSettings: [.linkedFramework("AppKit")]),
        .executableTarget(name: "MacDuo", dependencies: ["FoldCore", "TouchBarBridge"]),
        .testTarget(name: "FoldCoreTests", dependencies: ["FoldCore"])
    ]
)
