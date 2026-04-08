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
    project.units[0].lithologyColorHex = "#1A2B3C"
    project.units[0].grainSize = .silt

    let store = JSONProjectStore()
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-roundtrip-\(UUID().uuidString).json")

    let document = ProjectDocument(logs: [project])
    try store.save(document, to: tempFile)
    let loaded = try store.load(url: tempFile)

    #expect(loaded.logs.count == 1)
    #expect(loaded.logs[0] == project)
}

@Test
func loadingLegacySingleProjectJSONBuildsSingleLogDocument() throws {
    let legacy = Project.sample
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(legacy)

    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-legacy-\(UUID().uuidString).json")
    try data.write(to: tempFile, options: .atomic)

    let store = JSONProjectStore()
    let loaded = try store.load(url: tempFile)

    #expect(loaded.logs.count == 1)
    #expect(loaded.logs[0].metadata.title == legacy.metadata.title)
    #expect(loaded.logs[0].metadata.author == legacy.metadata.author)
    #expect(loaded.logs[0].settings == legacy.settings)
    #expect(loaded.logs[0].units == legacy.units)
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
    #expect(decoded.pointFeatureIconSize == 8.0)
    #expect(decoded.depthScaleUnit == .meter)
    #expect(decoded.useAbsoluteAltitude == false)
    #expect(decoded.zeroLevelAltitudeMeters == nil)
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
        showLogTitle: false,
        pointFeatureIconSize: 9.5,
        useAbsoluteAltitude: true,
        zeroLevelAltitudeMeters: 123.0
    )
    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(ProjectSettings.self, from: data)
    #expect(decoded.showGrid == true)
    #expect(decoded.showLegend == false)
    #expect(decoded.showScale == false)
    #expect(decoded.showLogTitle == false)
    #expect(decoded.pointFeatureIconSize == 9.5)
    #expect(decoded.useAbsoluteAltitude == true)
    #expect(decoded.zeroLevelAltitudeMeters == 123.0)
}

@Test
func stratigraphicUnitLegacyJSONWithoutLithologyColorDecodesWithNilCustomColor() throws {
    let legacyJSON = """
    {
      "id": "\(UUID().uuidString)",
      "name": "Layer",
      "thickness": 1.2,
      "lithology": "Limestone",
      "pointFeatures": []
    }
    """

    let decoded = try JSONDecoder().decode(StratigraphicUnit.self, from: Data(legacyJSON.utf8))
    #expect(decoded.lithologyColorHex == nil)
}

@Test
func stratigraphicUnitEncodesCanonicalUSGSLithologyCode() throws {
    let unit = StratigraphicUnit(name: "Layer", thickness: 1.2, usgsLithologyCode: 627)
    let data = try JSONEncoder().encode(unit)
    let json = String(decoding: data, as: UTF8.self)
    #expect(json.contains("\"usgsLithologyCode\":627"))
    #expect(!json.contains("\"lithology\""))
}
