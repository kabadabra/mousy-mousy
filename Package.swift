// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "MousyMousy",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "MousyCore"),
        .executableTarget(name: "MousyMousy", dependencies: ["MousyCore"]),
        .testTarget(name: "MousyCoreTests", dependencies: ["MousyCore"]),
    ]
)
