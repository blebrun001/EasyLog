import Testing
@testable import EasyLogKit

@Test
func pointFeatureIconCatalogMapsAllFeatureTypes() {
    for featureType in PointFeatureType.allCases {
        #expect(PointFeatureIconCatalog.token(for: featureType) != nil)
    }
}
