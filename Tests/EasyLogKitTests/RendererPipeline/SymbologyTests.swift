import Foundation
import Testing
@testable import EasyLogKit

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
    let activeProfile = EasyLogKitBundle.resourceProfile
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
    let resolver = USGSSymbolAssetResolver(bundle: EasyLogKitBundle.resources, profile: .dev)
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
func runtimeUSGSResourcesAreBundled() {
    let bundle = EasyLogKitBundle.resources
    let resourceRoot = bundle.resourceURL
    #expect(resourceRoot != nil)

    guard let resourceRoot else { return }
    let isolatedFolder = resourceRoot.appending(path: "isolated", directoryHint: .isDirectory)
    let catalogFile = resourceRoot.appending(path: "USGSRuntime/ResourceCatalog.release.json")
    #expect(FileManager.default.fileExists(atPath: isolatedFolder.path))
    #expect(FileManager.default.fileExists(atPath: catalogFile.path))
}

@Test
func usgsTilesRemainDiverseAcrossCatalog() {
    let renderableCodes = Set(SymbologyLibrary.supportedUSGSCodes.map(SymbologyLibrary.renderableUSGSCode(forSelectionCode:)))
    var uniqueTileHashes = Set<Int>()

    for code in renderableCodes {
        guard let tile = USGSEPSSymbolRenderer.pngTileData(for: code) else {
            Issue.record("Missing tile for code \(code)")
            continue
        }
        uniqueTileHashes.insert(tile.data.hashValue)
    }

    // If the renderer falls back globally, this number collapses quickly.
    #expect(uniqueTileHashes.count >= 100)
}

@Test
func closeLithologyAlternativesUseDistinctTiles() {
    let pairs: [(Int, Int)] = [
        (601, 602),
        (605, 606),
        (609, 610),
        (620, 621),
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
