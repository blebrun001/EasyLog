import Foundation
import Testing
@testable import EasyLogKit

@Test
func sceneLayoutLabelsAreEnglishOnly() {
    #expect(SceneLayout.legendTitle() == "Legend")
    #expect(SceneLayout.grainScaleTitle() == "Grain Size")
    #expect(SceneLayout.grainScaleFineLabel() == "Fine")
    #expect(SceneLayout.grainScaleSiltLabel() == "Silt")
    #expect(SceneLayout.grainScaleSandLabel() == "Sand")
    #expect(SceneLayout.grainScaleCoarseLabel() == "Coarse")
    #expect(SceneLayout.scaleAxisTitle(unit: .meter, zeroLevelAltitudeInMeters: nil) == "Depth (m)")
    #expect(SceneLayout.scaleAxisTitle(unit: .meter, zeroLevelAltitudeInMeters: 20) == "Altitude (m)")
}

@Test
func sceneLayoutUntitledUnitLabelIsEnglish() {
    let unnamedUnit = RenderedUnit(
        id: UUID(),
        name: " ",
        thickness: 1.0,
        lithology: "Test",
        symbol: .sandstone,
        fillHex: "#FFFFFF",
        rect: RectD(x: 0, y: 0, width: 10, height: 10)
    )

    #expect(SceneLayout.unitPrimaryLabel(unnamedUnit) == "Untitled Unit")
}

@Test
func validatorMessagesAreEnglishOnly() {
    let project = Project(
        settings: ProjectSettings(verticalScale: 0, baseFontSize: 0),
        units: [
            StratigraphicUnit(
                name: "",
                thickness: 0,
                usgsLithologyCode: -1,
                grainSize: .sand
            )
        ]
    )

    let messages = Set(ProjectValidator.validate(project).map(\.message))
    #expect(messages.contains("A unit has no name."))
    #expect(messages.contains(where: { $0.contains("must have thickness > 0") }))
    #expect(messages.contains(where: { $0.contains("unsupported USGS lithology code") }))
}
