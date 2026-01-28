// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "claude-notify",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "claude-notify",
            path: "Sources"
        )
    ]
)
