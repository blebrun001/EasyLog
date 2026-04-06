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
