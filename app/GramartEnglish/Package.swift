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
            path: "Sources",
            // F009 (v1.10.0). Semantic.{success,warning,error} resolve via
            // `Color("Name", bundle: .module)` against this catalog, which
            // ships light + dark colorset variants tuned to ≥ 4.5:1
            // contrast on the macOS window background.
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "GramartEnglishTests",
            dependencies: ["GramartEnglish"],
            path: "Tests",
            exclude: ["UI"]
        ),
    ]
)
