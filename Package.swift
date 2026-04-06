// swift-tools-version: 6.0
import PackageDescription

// Defines the package graph: CakeKit library + CakeApp executable.
// CakeKit bundles only runtime-ready USGS assets (not raw authoring EPS files).
let package = Package(
    name: "Cake",
    platforms: [
        // Keep SwiftPM on the highest named API constant while Xcode target is set to 26.0.
        .macOS(.v15)
    ],
    products: [
        .library(name: "CakeKit", targets: ["CakeKit"]),
        .executable(name: "CakeApp", targets: ["CakeApp"])
    ],
    targets: [
        .target(
            name: "CakeKit",
            path: "Sources/CakeKit",
            exclude: [
                "Resources/USGS/11A02/ai8",
                "Resources/USGS/11A02/cs2",
                "Resources/USGS/11A02/raster/cs2",
                "Resources/USGS/11A02/pdf/cs2",
                "Resources/USGS/11A02/work",
                "Resources/USGS/11A02/manifest.json",
                "Resources/USGS/11A02/symbol-index.json"
            ],
            resources: [
                .copy("Resources/USGS/11A02/raster"),
                .copy("Resources/USGS/11A02/pdf"),
                .copy("Resources/USGSRuntime")
            ]
        ),
        .executableTarget(
            name: "CakeApp",
            dependencies: ["CakeKit"],
            path: "Sources/CakeApp",
            resources: [
                .copy("Resources/Assets.xcassets"),
                .copy("Resources/Cake.icns")
            ]
        ),
        .testTarget(
            name: "CakeKitTests",
            dependencies: ["CakeKit"],
            path: "Tests/CakeKitTests"
        )
    ]
)
