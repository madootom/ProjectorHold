// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ProjectorHold",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ProjectorHold", path: "Sources/ProjectorHold")
    ]
)
