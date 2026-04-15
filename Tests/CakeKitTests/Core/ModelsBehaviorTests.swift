import Foundation
import Testing
@testable import CakeKit

@Test
func unitPointFeatureClampsDensityAndNormalizesColor() {
    let low = UnitPointFeature(type: .paleoRoots, density: -2, colorHex: "ff00aa")
    let high = UnitPointFeature(type: .paleoRoots, density: 10, colorHex: "bad")

    #expect(low.density == 0)
    #expect(low.colorHex == "#FF00AA")
    #expect(high.density == 1)
    #expect(high.colorHex == nil)
    #expect(high.resolvedColorHex == UnitPointFeature.defaultColorHex)
}

@Test
func unitPointFeatureDecodesLegacyConcentrationAndEncodesDensity() throws {
    let json = """
    {
      "type": "paleoRoots",
      "concentration": "high",
      "colorHex": "#123abc"
    }
    """

    let decoded = try JSONDecoder().decode(UnitPointFeature.self, from: Data(json.utf8))
    #expect(decoded.density == 0.75)
    #expect(decoded.colorHex == "#123ABC")

    let encoded = try JSONEncoder().encode(decoded)
    let output = String(decoding: encoded, as: UTF8.self)
    #expect(output.contains("\"density\""))
    #expect(!output.contains("\"concentration\""))
}

@Test
func stratigraphicUnitNormalizesLithologyColorInInitAndCoding() throws {
    let unit = StratigraphicUnit(name: "U", thickness: 2, usgsLithologyCode: 627, lithologyColorHex: "00aa11")
    #expect(unit.lithologyColorHex == "#00AA11")

    let data = try JSONEncoder().encode(unit)
    let decoded = try JSONDecoder().decode(StratigraphicUnit.self, from: data)
    #expect(decoded.lithologyColorHex == "#00AA11")
}

@Test
func projectSettingsDecodeDefaultsNewFlagsAndBounds() throws {
    let json = """
    {
      "verticalScale": 10,
      "baseFontSize": 11,
      "showGrid": true,
      "showLegend": false,
      "showScale": false,
      "showLogTitle": false,
      "symbolScale": 0,
      "pointFeatureIconSize": 999
    }
    """

    let decoded = try JSONDecoder().decode(ProjectSettings.self, from: Data(json.utf8))
    #expect(decoded.showGrainSizeScale == true)
    #expect(decoded.showUSGSCodesInLithologyLabels == true)
    #expect(decoded.symbolScale == 0.05)
    #expect(decoded.pointFeatureIconSize == ProjectSettings.pointFeatureIconSizeRange.upperBound)
}
