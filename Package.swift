// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIDictApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AIDictApp",
            dependencies: [],
            path: "Sources/AIDictApp"
        )
    ]
)
