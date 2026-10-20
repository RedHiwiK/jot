// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Jot",
            path: "Sources/Jot"
        ),
        .testTarget(name: "JotTests", dependencies: ["Jot"])
    ]
)
