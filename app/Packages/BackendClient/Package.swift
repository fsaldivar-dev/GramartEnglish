// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BackendClient",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BackendClient", targets: ["BackendClient"]),
    ],
    targets: [
        .target(name: "BackendClient"),
        .testTarget(name: "BackendClientTests", dependencies: ["BackendClient"]),
    ]
)
