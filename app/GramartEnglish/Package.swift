// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GramartEnglish",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "GramartEnglish", targets: ["GramartEnglish"]),
    ],
    dependencies: [
        .package(path: "../Packages/LessonKit"),
        .package(path: "../Packages/BackendClient"),
    ],
    targets: [
        .executableTarget(
            name: "GramartEnglish",
            dependencies: [
                .product(name: "LessonKit", package: "LessonKit"),
                .product(name: "BackendClient", package: "BackendClient"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GramartEnglishTests",
            dependencies: ["GramartEnglish"],
            path: "Tests",
            exclude: ["UI"]
        ),
    ]
)
