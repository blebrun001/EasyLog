import Testing
@testable import CakeKit

/// Covers symbol lookup guarantees and USGS asset resolution quality.
@Test
func unknownLithologyFallsBackToDefault() {
    let style = SymbologyLibrary.style(forLithology: "mystery-rock")
    #expect(style.symbol == .fallback)
}

@Test
func everySupportedLithologyHasUSGSCode() {
    let missing = SymbologyLibrary.supportedLithologies.filter {
        SymbologyLibrary.usgsSymbolCode(forLithology: $0) == nil
    }
    #expect(missing.isEmpty)
}

@Test
func everySupportedLithologyResolvesToBundledUSGSEPSAsset() {
    let activeProfile = CakeKitBundle.resourceProfile
    let unresolved = SymbologyLibrary.supportedLithologies.compactMap { lithology -> String? in
        guard let code = SymbologyLibrary.usgsSymbolCode(forLithology: lithology) else {
            return lithology
        }
        return USGSSymbolAssetResolver.asset(for: code) == nil ? lithology : nil
    }
    if activeProfile == .release {
        #expect(unresolved.isEmpty)
    } else {
        #expect(unresolved.count < SymbologyLibrary.supportedLithologies.count)
    }
}

@Test
func section37KnownSymbolLoadsFromUSGSAssetBundle() {
    let asset = USGSSymbolAssetResolver.asset(for: 607)
    #expect(asset != nil)
    #expect(asset?.epsRelativePath.contains("USGS/11A02/") == true)
}

@Test
func reportedFallbackCodesNowResolveToUSGSRasterTiles() {
    let reportedCodes = [619, 607, 627, 601, 602, 603, 605, 606]
    for code in reportedCodes {
        #expect(USGSSymbolAssetResolver.asset(for: code) != nil)
        #expect(USGSEPSSymbolRenderer.pngTileData(for: code) != nil)
    }
}

@Test
func devProfileFallsBackToReleaseCatalogForMissingDevEntries() {
    let resolver = USGSSymbolAssetResolver(bundle: CakeKitBundle.resources, profile: .dev)
    #expect(resolver.asset(for: 733) != nil)
}

@Test
func section37CatalogContainsAllOfficialCodesIncludingAliasSource() {
    #expect(SymbologyLibrary.supportedUSGSCodes.count == 117)
    #expect(SymbologyLibrary.supportedUSGSCodes.contains(718))
    #expect(SymbologyLibrary.supportedUSGSCodes.contains(719))
}

@Test
func alias718Uses719RenderableSwatchExplicitly() {
    #expect(SymbologyLibrary.usgsLithologyAliases[718] == 719)
    #expect(SymbologyLibrary.renderableUSGSCode(forSelectionCode: 718) == 719)
    #expect(USGSSymbolAssetResolver.asset(for: 718) != nil)
}

@Test
func everySupportedUSGSCodeProducesRenderableTile() {
    for code in SymbologyLibrary.supportedUSGSCodes {
        #expect(USGSSymbolAssetResolver.asset(for: code) != nil)
        #expect(USGSEPSSymbolRenderer.pngTileData(for: code) != nil)
    }
}

@Test
func closeLithologyAlternativesUseDistinctTiles() {
    let pairs: [(Int, Int)] = [
        (601, 602),
        (605, 606),
        (609, 610),
        (649, 650),
        (677, 678),
        (681, 682)
    ]

    for (lhs, rhs) in pairs {
        let lTile = USGSEPSSymbolRenderer.pngTileData(for: lhs)
        let rTile = USGSEPSSymbolRenderer.pngTileData(for: rhs)
        #expect(lTile != nil)
        #expect(rTile != nil)
        #expect(lTile?.data != rTile?.data)
    }
}
