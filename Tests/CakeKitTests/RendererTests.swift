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
func legendContainsOnlyUsedSymbols() {
    let project = Project(
        units: [
            StratigraphicUnit(name: "A", thickness: 2, lithology: "Massive sand or sandstone"),
            StratigraphicUnit(name: "B", thickness: 2, lithology: "Crossbedded sand or sandstone (1st option)"),
            StratigraphicUnit(name: "C", thickness: 2, lithology: "Limestone")
        ]
    )
    let renderer = CakeRenderer()
    let scene = renderer.makeScene(project: project)

    #expect(scene.legend.count == 2)
    #expect(scene.legend[0].symbol == .sandstone)
    #expect(scene.legend[1].symbol == .limestone)
}
