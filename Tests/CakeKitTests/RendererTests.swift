import Testing
@testable import CakeKit

@Test
func rendererProducesStackedUnitsWithoutOverlap() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone"),
            StratigraphicUnit(name: "B", thickness: 3, lithology: "Sandy or silty shale"),
            StratigraphicUnit(name: "C", thickness: 1.5, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)

    #expect(scene.units.count == 3)
    let first = scene.units[0].rect
    let second = scene.units[1].rect
    let third = scene.units[2].rect
    #expect(first.y + first.height == second.y)
    #expect(second.y + second.height == third.y)
}

@Test
func legendContainsEveryUsedUSGSSymbolCode() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone"),
            StratigraphicUnit(name: "B", thickness: 2, lithology: "Crossbedded sand or sandstone (1st option)"),
            StratigraphicUnit(name: "C", thickness: 2, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)

    #expect(scene.legend.count == 3)
    #expect(scene.legend[0].symbol == .sandstone)
    #expect(scene.legend[0].usgsSymbolCode == 607)
    #expect(scene.legend[1].symbol == .sandstone)
    #expect(scene.legend[1].usgsSymbolCode == 609)
    #expect(scene.legend[2].symbol == .limestone)
    #expect(scene.legend[2].usgsSymbolCode == 627)
}

@Test
func sceneCarriesConfiguredSymbolScale() {
    let project = Project(
        settings: ProjectSettings(symbolScale: 1.8),
        units: [
            StratigraphicUnit(name: "A", thickness: 1, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)
    #expect(scene.symbolScale == 1.8)
}

@Test
func pointFeaturesAppearInLegendOnlyWhenUsed() {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "A",
                thickness: 2,
                lithology: "Massive sand or sandstone",
                pointFeatures: [
                    UnitPointFeature(type: .archaeologicalBoneFragments, concentration: .low)
                ]
            ),
            StratigraphicUnit(
                name: "B",
                thickness: 2,
                lithology: "Limestone",
                pointFeatures: [
                    UnitPointFeature(type: .hydroDissolutionTraces, concentration: .high)
                ]
            )
        ]
    )

    let scene = CakeRenderer().makeScene(project: project)
    let pointLegendItems = scene.legend.filter { $0.pointSymbol != nil }

    #expect(pointLegendItems.count == 2)
    #expect(pointLegendItems.contains(where: { $0.label.contains("fragments osseux") }))
    #expect(pointLegendItems.contains(where: { $0.label.contains("traces de dissolution") }))
}

@Test
func highConcentrationProducesMorePointSymbolsAndStaysInsideUnit() {
    let unit = StratigraphicUnit(
        name: "A",
        thickness: 4,
        lithology: "Massive sand or sandstone",
        pointFeatures: [
            UnitPointFeature(type: .archaeologicalBoneFragments, concentration: .low),
            UnitPointFeature(type: .archaeologicalArtifacts, concentration: .high)
        ]
    )
    let scene = CakeRenderer().makeScene(project: Project(units: [unit]))
    let renderedUnit = scene.units[0]
    let rect = renderedUnit.rect

    let lowCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalBoneFragments }.count
    let highCount = renderedUnit.pointFeatures.filter { $0.type == .archaeologicalArtifacts }.count
    #expect(highCount > lowCount)
    #expect(lowCount > 0)

    for point in renderedUnit.pointFeatures {
        #expect(point.centerX >= rect.x)
        #expect(point.centerX <= rect.x + rect.width)
        #expect(point.centerY >= rect.y)
        #expect(point.centerY <= rect.y + rect.height)
    }
}
