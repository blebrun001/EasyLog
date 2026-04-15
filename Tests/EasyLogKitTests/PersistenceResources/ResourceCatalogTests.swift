import Foundation
import Testing
@testable import EasyLogKit

@Test
func resourceCatalogParsesAndResolvesPDFURL() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-resource-catalog-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let isolatedPath = root.appending(path: "isolated/symbol.pdf")
    try FileManager.default.createDirectory(at: isolatedPath.deletingLastPathComponent(), withIntermediateDirectories: true)

    let pdfData = Data("%PDF-1.4\n".utf8)
    try pdfData.write(to: isolatedPath)

    let manifest = """
    {
      "schemaVersion": 2,
      "profile": "dev",
      "sourceIndex": "USGS/11A02/symbol-index.json",
      "totalEntries": 1,
      "generatedBy": "tests",
      "entries": [
        {
          "id": "usgs-code-607-ai8",
          "symbolId": "code:607",
          "code": 607,
          "label": "Test Symbol",
          "section": "Sec37",
          "sourceFileNameUSGS": "FGDCgeostdTM11A2_A-37-01ai8.pdf",
          "variant": "ai8",
          "epsRelativePath": "USGS/11A02/ai8/source.eps",
          "pageSizePoints": { "width": 612, "height": 792 },
          "symbolRect": { "x": 1, "y": 2, "width": 3, "height": 4 },
          "isolatedPdfPath": "isolated/symbol.pdf",
          "pdf": { "path": "pdf/ai8/symbol.pdf", "sha256": "e5c62df5dab5c87b6a015ef3d43597074d1eec433b15f51aec63b8582d0e4ab4", "bytes": 9 }
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

    let entry = try catalog.preferredEntry(forCode: 607)
    let url = try catalog.resolvedPDFURL(for: entry, validateHashes: true)

    #expect(url.path == isolatedPath.path)
}

@Test
func resourceCatalogThrowsForMissingCode() throws {
    let manifest = """
    {
      "schemaVersion": 2,
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
        _ = try catalog.preferredEntry(forCode: 999)
    }
}

@Test
func resourceCatalogThrowsOnHashMismatch() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "easylog-resource-catalog-mismatch-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let isolatedPath = root.appending(path: "isolated/symbol.pdf")
    try FileManager.default.createDirectory(at: isolatedPath.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("%PDF-1.4\n".utf8).write(to: isolatedPath)

    let manifest = """
    {
      "schemaVersion": 2,
      "profile": "dev",
      "sourceIndex": "USGS/11A02/symbol-index.json",
      "totalEntries": 1,
      "generatedBy": "tests",
      "entries": [
        {
          "id": "usgs-code-607-ai8",
          "symbolId": "code:607",
          "code": 607,
          "label": "Test Symbol",
          "section": "Sec37",
          "sourceFileNameUSGS": "FGDCgeostdTM11A2_A-37-01ai8.pdf",
          "variant": "ai8",
          "epsRelativePath": "USGS/11A02/ai8/source.eps",
          "pageSizePoints": { "width": 612, "height": 792 },
          "symbolRect": { "x": 1, "y": 2, "width": 3, "height": 4 },
          "isolatedPdfPath": "isolated/symbol.pdf",
          "pdf": { "path": "pdf/ai8/symbol.pdf", "sha256": "deadbeef", "bytes": 9 }
        }
      ]
    }
    """

    let provider = DirectoryResourceProvider(rootURL: root)
    let catalog = try USGSResourceCatalog(profile: .dev, provider: provider, manifestData: Data(manifest.utf8))
    let entry = try catalog.preferredEntry(forCode: 607)

    #expect(throws: USGSResourceCatalog.CatalogError.self) {
        _ = try catalog.resolvedPDFURL(for: entry, validateHashes: true)
    }
}
