// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Jarbo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Jarbo", targets: ["Jarbo"])],
    targets: [
        .executableTarget(name: "Jarbo", path: "Sources/Jarbo"),
        .testTarget(name: "JarboTests", dependencies: ["Jarbo"], path: "Tests/JarboTests"),
    ]
)
