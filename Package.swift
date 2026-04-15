// swift-tools-version: 6.0
import PackageDescription

// Defines the package graph: EasyLogKit library + EasyLogApp executable.
// EasyLogKit bundles only runtime-ready USGS assets (not raw authoring EPS files).
let package = Package(
    name: "EasyLog",
    platforms: [
        // Keep SwiftPM on the highest named API constant while Xcode target is set to 26.0.
        .macOS(.v15)
    ],
    products: [
        .library(name: "EasyLogKit", targets: ["EasyLogKit"]),
        .executable(name: "EasyLogApp", targets: ["EasyLogApp"])
    ],
    targets: [
        .target(
            name: "EasyLogKit",
            path: "Sources/EasyLogKit",
            exclude: [
                "Resources/USGS/11A02/ai8",
                "Resources/USGS/11A02/cs2",
                "Resources/USGS/11A02/raster",
                "Resources/USGS/11A02/work",
                "Resources/USGS/11A02/manifest.json",
                "Resources/USGS/11A02/symbol-index.json"
            ],
            resources: [
                .copy("Resources/USGS/11A02/pdf"),
                .copy("Resources/isolated"),
                .copy("Resources/USGSRuntime")
            ]
        ),
        .executableTarget(
            name: "EasyLogApp",
            dependencies: ["EasyLogKit"],
            path: "Sources/EasyLogApp",
            resources: [
                .copy("Resources/Assets.xcassets"),
                .copy("Resources/EasyLog.icns")
            ]
        ),
        .testTarget(
            name: "EasyLogKitTests",
            dependencies: ["EasyLogKit"],
            path: "Tests/EasyLogKitTests"
        )
    ]
)
