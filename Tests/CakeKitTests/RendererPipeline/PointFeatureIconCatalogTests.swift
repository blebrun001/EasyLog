import Testing
@testable import CakeKit

@Test
func pointFeatureIconCatalogMapsAllFeatureTypes() {
    for featureType in PointFeatureType.allCases {
        #expect(PointFeatureIconCatalog.token(for: featureType) != nil)
    }
}
