// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidAwake",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "LidAwake", targets: ["LidAwake"]),
    ],
    targets: [
        .executableTarget(name: "LidAwake"),
    ]
)
