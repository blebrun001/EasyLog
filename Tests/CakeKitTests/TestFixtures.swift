import AppKit
import Foundation
@testable import CakeKit

func makeTempDirectory(prefix: String = "cake-tests") throws -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func makeTempFileURL(prefix: String, ext: String) -> URL {
    URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "\(prefix)-\(UUID().uuidString).\(ext)")
}

func makeBitmapContext(width: Int = 64, height: Int = 64) -> CGContext? {
    CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
}

func makeImage(width: Int = 64, height: Int = 64) -> CGImage {
    let context = makeBitmapContext(width: width, height: height)!
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

func makeSimpleScene(canvasWidth: Double = 180, canvasHeight: Double = 140) -> RenderScene {
    RenderScene(
        title: "Fixture",
        canvasSize: CGSizeDTO(width: canvasWidth, height: canvasHeight),
        logColumnRect: RectD(x: 20, y: 20, width: 60, height: 90),
        units: [
            RenderedUnit(
                id: UUID(),
                name: "A",
                thickness: 2,
                lithology: "Limestone",
                symbol: .limestone,
                usgsSymbolCode: 627,
                fillHex: "#EAEAEA",
                rect: RectD(x: 20, y: 20, width: 60, height: 90),
                grainSize: .sand,
                pointFeatures: [
                    RenderedPointFeature(
                        type: .paleoRoots,
                        iconToken: .roots,
                        symbol: .circle,
                        colorHex: "#111111",
                        centerX: 45,
                        centerY: 65,
                        size: 8
                    )
                ]
            )
        ],
        legend: [
            LegendItem(label: "Limestone", symbol: .limestone, usgsSymbolCode: 627, fillHex: "#EAEAEA"),
            LegendItem(
                label: "Roots",
                symbol: .fallback,
                pointIconToken: .roots,
                pointSymbol: .circle,
                pointColorHex: "#111111"
            )
        ],
        ticks: [ScaleTick(depth: 0, y: 20), ScaleTick(depth: 1, y: 65), ScaleTick(depth: 2, y: 110)],
        baseFontSize: 12,
        showsGrid: true,
        showsLegend: true,
        showsScale: true,
        showsGrainSizeScale: true,
        showsLogTitle: true,
        symbolScale: 1.0,
        pointFeatureIconSize: 8.0,
        depthScaleUnit: .meter,
        useAbsoluteAltitude: false,
        zeroLevelAltitudeMeters: nil
    )
}
