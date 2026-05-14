// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LessonKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LessonKit", targets: ["LessonKit"]),
    ],
    targets: [
        .target(name: "LessonKit"),
        .testTarget(name: "LessonKitTests", dependencies: ["LessonKit"]),
    ]
)
