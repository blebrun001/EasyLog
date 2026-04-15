import Foundation
import Testing
@testable import CakeKit

private enum CompositeTestError: Error {
    case failed
}

private final class RecordingSVGExporter: SVGExporting {
    var calls = 0
    var shouldFail = false

    func export(scene _: RenderScene, to _: URL, canvas _: CGSizeDTO) throws {
        if shouldFail {
            throw CompositeTestError.failed
        }
        calls += 1
    }
}

@Test
func jpgExporterWritesNonEmptyJPEGFile() throws {
    let scene = makeSimpleScene(canvasWidth: 120, canvasHeight: 80)
    let url = makeTempFileURL(prefix: "jpg-export", ext: "jpg")

    try JPGExporter().export(scene: scene, to: url, options: ExportOptions(format: .jpg, dpi: 144))

    let data = try Data(contentsOf: url)
    #expect(!data.isEmpty)
}

@Test
func compositeExporterRoutesToSVGAndJPG() throws {
    let scene = makeSimpleScene(canvasWidth: 120, canvasHeight: 80)
    let svg = RecordingSVGExporter()
    let exporter = CompositeExporter(svgExporter: svg, jpgExporter: JPGExporter())
    let jpgURL = makeTempFileURL(prefix: "composite", ext: "jpg")

    try exporter.export(scene: scene, to: makeTempFileURL(prefix: "composite", ext: "svg"), options: ExportOptions(format: .svg, dpi: 72))
    try exporter.export(scene: scene, to: jpgURL, options: ExportOptions(format: .jpg, dpi: 144))

    #expect(svg.calls == 1)
    #expect((try? Data(contentsOf: jpgURL).isEmpty) == false)
}

@Test
func compositeExporterPropagatesUnderlyingErrors() {
    let scene = makeSimpleScene()
    let svg = RecordingSVGExporter()
    svg.shouldFail = true
    let exporter = CompositeExporter(svgExporter: svg)

    #expect(throws: (any Error).self) {
        try exporter.export(scene: scene, to: makeTempFileURL(prefix: "composite-fail", ext: "svg"), options: ExportOptions(format: .svg))
    }
}
