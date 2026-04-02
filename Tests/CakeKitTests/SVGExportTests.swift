import Foundation
import Testing
@testable import CakeKit

@Test
func svgExportContainsCoreGroupsAndGridWhenEnabled() throws {
    let project = Project(
        settings: ProjectSettings(showGrid: true),
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone", grainSize: .sand),
            StratigraphicUnit(name: "B", thickness: 1.5, lithology: "Limestone", grainSize: .granule)
        ]
    )
    let scene = CakeRenderer().makeScene(project: project)
    let exporter = SVGExporter()
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-svg-\(UUID().uuidString).svg")

    try exporter.export(scene: scene, to: outputURL, canvas: scene.canvasSize)
    let content = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(content.contains("<g id=\"units\">"))
    #expect(content.contains("<g id=\"scale\""))
    #expect(content.contains("<g id=\"legend\">"))
    #expect(content.contains("<g id=\"grid\""))
    #expect(content.contains("Depth (m)"))
}
