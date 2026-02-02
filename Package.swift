// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sift",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Sift",
            path: "Sources/Sift"
        )
    ]
)
