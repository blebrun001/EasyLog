import Foundation
import Testing
@testable import EasyLogKit

/// Verifies that SVG exports include expected structural groups and layers.
@Test
func svgExportContainsCoreGroupsAndGridWhenEnabled() throws {
    let project = Project(
        settings: ProjectSettings(showGrid: true),
        units: [
            StratigraphicUnit(name: "A", thickness: 2, usgsLithologyCode: usgsCode("Massive sand or sandstone"), grainSize: .sand),
            StratigraphicUnit(name: "B", thickness: 1.5, usgsLithologyCode: usgsCode("Limestone"), grainSize: .granule)
        ]
    )
    let scene = EasyLogRenderer().makeScene(project: project)
    let exporter = SVGExporter()
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-svg-\(UUID().uuidString).svg")

    try exporter.export(scene: scene, to: outputURL, canvas: scene.canvasSize)
    let content = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(content.contains("<g id=\"units\">"))
    #expect(content.contains("<g id=\"scale\""))
    #expect(content.contains("<g id=\"legend\">"))
    #expect(content.contains("<g id=\"grid\""))
    #expect(content.contains("Depth (m)"))
}

@Test
func svgExportUsesCustomLithologyFillForUnitsAndLegend() throws {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 2,
                usgsLithologyCode: usgsCode("Limestone"),
                lithologyColorHex: "#12ab34"
            )
        ]
    )
    let scene = EasyLogRenderer().makeScene(project: project)
    let exporter = SVGExporter()
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-svg-color-\(UUID().uuidString).svg")

    try exporter.export(scene: scene, to: outputURL, canvas: scene.canvasSize)
    let content = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(content.contains("fill=\"#12AB34\" class=\"unit-fill\""))
    #expect(content.contains("width=\"28\" height=\"18\" fill=\"#12AB34\""))
}

@Test
func svgExportUsesUnitNameOnlyForPrimaryUnitLabel() throws {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "Unit Alpha",
                thickness: 2.5,
                usgsLithologyCode: usgsCode("Limestone"),
                grainSize: .sand
            )
        ]
    )
    let scene = EasyLogRenderer().makeScene(project: project)
    let exporter = SVGExporter()
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-svg-unit-label-\(UUID().uuidString).svg")

    try exporter.export(scene: scene, to: outputURL, canvas: scene.canvasSize)
    let content = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(content.contains(">Unit Alpha<"))
    #expect(!content.contains("Unit Alpha (2.5 m)"))
    #expect(!content.contains(">Limestone<"))
}

@Test
func svgExportUsesAltitudeAxisLabelWhenZeroLevelAltitudeIsConfigured() throws {
    let project = Project(
        settings: ProjectSettings(useAbsoluteAltitude: true, zeroLevelAltitudeMeters: 123),
        units: [
            StratigraphicUnit(name: "A", thickness: 2, usgsLithologyCode: usgsCode("Limestone"))
        ]
    )
    let scene = EasyLogRenderer().makeScene(project: project)
    let exporter = SVGExporter()
    let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-svg-altitude-\(UUID().uuidString).svg")

    try exporter.export(scene: scene, to: outputURL, canvas: scene.canvasSize)
    let content = try String(contentsOf: outputURL, encoding: .utf8)

    #expect(content.contains("Altitude (m)"))
    #expect(!content.contains("Depth (m)"))
}
