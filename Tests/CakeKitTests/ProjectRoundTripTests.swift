import Foundation
import Testing
@testable import CakeKit

/// Guards project persistence compatibility and legacy decoding behavior.
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
    #expect(decoded.showLegend == true)
    #expect(decoded.showScale == true)
    #expect(decoded.showLogTitle == true)
}

@Test
func loadingMissingProjectFileThrowsFileError() {
    let store = JSONProjectStore()
    let missing = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-missing-\(UUID().uuidString).json")

    #expect(throws: (any Error).self) {
        _ = try store.load(url: missing)
    }
}

@Test
func loadingInvalidProjectDataThrowsInvalidDataError() throws {
    let store = JSONProjectStore()
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-invalid-\(UUID().uuidString).json")
    try Data("not-json".utf8).write(to: tempFile, options: .atomic)

    #expect(throws: ProjectStoreError.self) {
        _ = try store.load(url: tempFile)
    }
}

@Test
func projectSettingsShowGridRoundTripPersistsValue() throws {
    let settings = ProjectSettings(
        showGrid: true,
        showLegend: false,
        showScale: false,
        showLogTitle: false
    )
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(ProjectSettings.self, from: data)
    #expect(decoded.showGrid == true)
    #expect(decoded.showLegend == false)
    #expect(decoded.showScale == false)
    #expect(decoded.showLogTitle == false)
}
