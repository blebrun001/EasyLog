import Foundation
import Testing
@testable import CakeKit

@Test
func projectJSONRoundTripPreservesMWEFields() throws {
    var project = Project.sample
    project.metadata.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    project.metadata.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
    project.units[0].name = "Floodplain Mud"
    project.units[0].thickness = 1.45
    project.units[0].lithology = "Sandy or silty shale"
    project.units[0].grainSize = .silt

    let store = JSONProjectStore()
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-roundtrip-\(UUID().uuidString).json")

    try store.save(project, to: tempFile)
    let loaded = try store.load(url: tempFile)

    #expect(loaded == project)
}

@Test
func projectSettingsLegacyJSONWithPageSizeDecodesSuccessfully() throws {
    let legacyJSON = """
    {
      "verticalScale": 25,
      "pageSize": "letterPortrait",
      "baseFontSize": 12,
      "showGrid": false,
      "symbolScale": 1.0
    }
    """

    let decoded = try JSONDecoder().decode(ProjectSettings.self, from: Data(legacyJSON.utf8))

    #expect(decoded.verticalScale == 25)
    #expect(decoded.pageSize == .letterPortrait)
    #expect(decoded.baseFontSize == 12)
    #expect(decoded.symbolScale == 1.0)
    #expect(decoded.depthScaleUnit == .meter)
}
