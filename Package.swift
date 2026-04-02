// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cake",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CakeKit", targets: ["CakeKit"]),
        .executable(name: "CakeApp", targets: ["CakeApp"])
    ],
    targets: [
        .target(
            name: "CakeKit",
            path: "Sources/CakeKit"
        ),
        .executableTarget(
            name: "CakeApp",
            dependencies: ["CakeKit"],
            path: "Sources/CakeApp"
        ),
        .testTarget(
            name: "CakeKitTests",
            dependencies: ["CakeKit"],
            path: "Tests/CakeKitTests"
        )
    ]
)
