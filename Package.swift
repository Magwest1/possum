// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Possum",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PossumCore"),
        .executableTarget(name: "Possum", dependencies: ["PossumCore"]),
        .executableTarget(name: "PossumHelper", dependencies: ["PossumCore"]),
        .testTarget(name: "PossumCoreTests", dependencies: ["PossumCore"]),
    ],
    swiftLanguageModes: [.v5]
)
