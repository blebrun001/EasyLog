import Foundation
import Testing
@testable import EasyLogKit

private struct MockLogRenderer: LogRenderer {
    let scene: RenderScene

    func makeScene(project _: Project) -> RenderScene {
        scene
    }
}

@Test
func sceneComputationServiceComputesValidationAndVisibleUSGSCodes() async {
    let scene = RenderScene(
        title: "Scene",
        canvasSize: CGSizeDTO(width: 200, height: 120),
        logColumnRect: RectD(x: 20, y: 20, width: 70, height: 70),
        units: [
            RenderedUnit(
                id: UUID(),
                name: "U1",
                thickness: 1,
                lithology: "Limestone",
                symbol: .limestone,
                usgsSymbolCode: 627,
                fillHex: "#CCCCCC",
                rect: RectD(x: 20, y: 20, width: 70, height: 40)
            )
        ],
        legend: [
            LegendItem(label: "Limestone", symbol: .limestone, usgsSymbolCode: 627, fillHex: "#CCCCCC"),
            LegendItem(label: "Sandstone", symbol: .sandstone, usgsSymbolCode: 607, fillHex: "#AAAAAA")
        ],
        ticks: [],
        baseFontSize: 12,
        showsGrid: false,
        showsLegend: true,
        showsScale: true,
        showsGrainSizeScale: true,
        showsLogTitle: true,
        symbolScale: 1,
        pointFeatureIconSize: 8,
        depthScaleUnit: .meter,
        useAbsoluteAltitude: false,
        zeroLevelAltitudeMeters: nil
    )

    let invalidProject = Project(
        settings: ProjectSettings(verticalScale: 0, baseFontSize: 0),
        units: [StratigraphicUnit(name: "", thickness: 0, usgsLithologyCode: -1)]
    )

    let service = SceneComputationService(renderer: MockLogRenderer(scene: scene))
    let result = await service.computeScene(project: invalidProject)

    #expect(result.scene.title == "Scene")
    #expect(!result.validationIssues.isEmpty)
    #expect(result.visibleUSGSCodes == [607, 627])
}

@Test
func sceneComputationServiceSyntheticRequiresAtLeastTwoLogsAndZeroLevels() async {
    let service = SceneComputationService(renderer: EasyLogRenderer())
    var a = Project.sample
    var b = Project.sample

    a.settings.zeroLevelAltitudeMeters = 100
    b.settings.zeroLevelAltitudeMeters = nil

    let tooFew = await service.computeSynthetic(logs: [a], selectedLogIndex: 0)
    #expect(tooFew.columns.isEmpty)

    let missingZero = await service.computeSynthetic(logs: [a, b], selectedLogIndex: 0)
    #expect(missingZero.columns.isEmpty)

    b.settings.zeroLevelAltitudeMeters = 98
    let valid = await service.computeSynthetic(logs: [a, b], selectedLogIndex: 0)
    #expect(valid.columns.count == 2)
}
