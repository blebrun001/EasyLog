import Foundation
import Testing
@testable import CakeKit

@Test
func resourceCatalogParsesAndResolvesEntryURLs() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-resource-catalog-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let pngPath = root.appending(path: "USGS/11A02/raster/ai8/symbol.png")
    let pdfPath = root.appending(path: "USGS/11A02/pdf/ai8/symbol.pdf")
    try FileManager.default.createDirectory(at: pngPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pdfPath.deletingLastPathComponent(), withIntermediateDirectories: true)

    let pngData = Data([0x89, 0x50, 0x4e, 0x47])
    let pdfData = Data("%PDF-1.4\n".utf8)
    try pngData.write(to: pngPath)
    try pdfData.write(to: pdfPath)

    let manifest = """
    {
      "schemaVersion": 1,
      "profile": "dev",
      "sourceIndex": "USGS/11A02/symbol-index.json",
      "totalEntries": 1,
      "generatedBy": "tests",
      "entries": [
        {
          "id": "usgs-607-ai8-test",
          "code": 607,
          "label": "Test Symbol",
          "variant": "ai8",
          "epsRelativePath": "USGS/11A02/ai8/source.eps",
          "pageSizePoints": { "width": 612, "height": 792 },
          "symbolRect": { "x": 1, "y": 2, "width": 3, "height": 4 },
          "png": { "path": "USGS/11A02/raster/ai8/symbol.png", "sha256": "0f4636c78f65d3639ece5a064b5ae753e3408614a14fb18ab4d7540d2c248543", "bytes": 4 },
          "pdf": { "path": "USGS/11A02/pdf/ai8/symbol.pdf", "sha256": "e5c62df5dab5c87b6a015ef3d43597074d1eec433b15f51aec63b8582d0e4ab4", "bytes": 9 }
        }
      ]
    }
    """

    let provider = DirectoryResourceProvider(rootURL: root)
    let catalog = try USGSResourceCatalog(
        profile: .dev,
        provider: provider,
        manifestData: Data(manifest.utf8)
    )

    let entry = try catalog.preferredEntry(for: 607)
    let urls = try catalog.resolvedURLs(for: entry, validateHashes: true)

    #expect(urls.pngURL.path == pngPath.path)
    #expect(urls.pdfURL.path == pdfPath.path)
}

@Test
func resourceCatalogThrowsForMissingCode() throws {
    let manifest = """
    {
      "schemaVersion": 1,
      "profile": "dev",
      "sourceIndex": "USGS/11A02/symbol-index.json",
      "totalEntries": 0,
      "generatedBy": "tests",
      "entries": []
    }
    """
    let provider = DirectoryResourceProvider(rootURL: URL(fileURLWithPath: NSTemporaryDirectory()))
    let catalog = try USGSResourceCatalog(profile: .dev, provider: provider, manifestData: Data(manifest.utf8))

    #expect(throws: USGSResourceCatalog.CatalogError.self) {
        _ = try catalog.preferredEntry(for: 999)
    }
}

@Test
func resourceCatalogThrowsOnHashMismatch() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-resource-catalog-mismatch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let pngPath = root.appending(path: "USGS/11A02/raster/ai8/symbol.png")
    let pdfPath = root.appending(path: "USGS/11A02/pdf/ai8/symbol.pdf")
    try FileManager.default.createDirectory(at: pngPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pdfPath.deletingLastPathComponent(), withIntermediateDirectories: true)

    try Data([1, 2, 3]).write(to: pngPath)
    try Data("%PDF-1.4\n".utf8).write(to: pdfPath)

    let manifest = """
    {
      "schemaVersion": 1,
      "profile": "dev",
      "sourceIndex": "USGS/11A02/symbol-index.json",
      "totalEntries": 1,
      "generatedBy": "tests",
      "entries": [
        {
          "id": "usgs-607-ai8-test",
          "code": 607,
          "label": "Test Symbol",
          "variant": "ai8",
          "epsRelativePath": "USGS/11A02/ai8/source.eps",
          "pageSizePoints": { "width": 612, "height": 792 },
          "symbolRect": { "x": 1, "y": 2, "width": 3, "height": 4 },
          "png": { "path": "USGS/11A02/raster/ai8/symbol.png", "sha256": "deadbeef", "bytes": 3 },
          "pdf": { "path": "USGS/11A02/pdf/ai8/symbol.pdf", "sha256": "e5c62df5dab5c87b6a015ef3d43597074d1eec433b15f51aec63b8582d0e4ab4", "bytes": 9 }
        }
      ]
    }
    """

    let provider = DirectoryResourceProvider(rootURL: root)
    let catalog = try USGSResourceCatalog(profile: .dev, provider: provider, manifestData: Data(manifest.utf8))
    let entry = try catalog.preferredEntry(for: 607)

    #expect(throws: USGSResourceCatalog.CatalogError.self) {
        _ = try catalog.resolvedURLs(for: entry, validateHashes: true)
    }
}
