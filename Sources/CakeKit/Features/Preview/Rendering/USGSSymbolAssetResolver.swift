import Foundation

public struct USGSSymbolRect: Codable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

public struct USGSSymbolAsset: Hashable {
    public let code: Int
    public let label: String
    public let variant: String
    public let epsRelativePath: String
    public let pngRelativePath: String
    public let pageSizePoints: CGSizeDTO
    public let symbolRect: USGSSymbolRect
    public let imageURL: URL
}

public final class USGSSymbolAssetResolver: @unchecked Sendable {
    public static let shared = USGSSymbolAssetResolver()

    private let entriesByCode: [Int: SymbolIndexEntry]

    public init(bundle: Bundle = CakeKitBundle.resources) {
        self.entriesByCode = Self.loadIndex(bundle: bundle)
    }

    public static func asset(for code: Int) -> USGSSymbolAsset? {
        shared.asset(for: code)
    }

    public func asset(for code: Int) -> USGSSymbolAsset? {
        let resolvedCode = Self.aliasCode[code] ?? code
        guard let entry = entriesByCode[resolvedCode] else { return nil }

        if let ai8 = entry.ai8, let asset = makeAsset(code: code, label: entry.label, variant: "ai8", variantEntry: ai8) {
            return asset
        }

        if let cs2 = entry.cs2, let asset = makeAsset(code: code, label: entry.label, variant: "cs2", variantEntry: cs2) {
            return asset
        }

        let fallbackVariant = entry.epsFile.contains("/cs2/") ? "cs2" : "ai8"
        let fallbackPNG = entry.epsFile
            .replacingOccurrences(of: "/ai8/", with: "/raster/ai8/")
            .replacingOccurrences(of: "/cs2/", with: "/raster/cs2/")
            .replacingOccurrences(of: ".eps", with: ".png")
        let fallbackURL = CakeKitBundle.resources.resourceURL?.appendingPathComponent(fallbackPNG)
        guard let fallbackURL, FileManager.default.fileExists(atPath: fallbackURL.path) else {
            return nil
        }
        return USGSSymbolAsset(
            code: code,
            label: entry.label,
            variant: fallbackVariant,
            epsRelativePath: entry.epsFile,
            pngRelativePath: fallbackPNG,
            pageSizePoints: CGSizeDTO(width: 612, height: 792),
            symbolRect: entry.symbolRect,
            imageURL: fallbackURL
        )
    }

    // Some officially listed codes have no separate EPS swatch in the published sheet.
    // In these cases we intentionally map to the closest paired option that exists.
    private static let aliasCode: [Int: Int] = [
        718: 719
    ]

    private func makeAsset(code: Int, label: String, variant: String, variantEntry: VariantEntry) -> USGSSymbolAsset? {
        guard let pngURL = CakeKitBundle.resources.resourceURL?.appendingPathComponent(variantEntry.pngFile),
              FileManager.default.fileExists(atPath: pngURL.path)
        else {
            return nil
        }

        return USGSSymbolAsset(
            code: code,
            label: label,
            variant: variant,
            epsRelativePath: variantEntry.epsFile,
            pngRelativePath: variantEntry.pngFile,
            pageSizePoints: variantEntry.pageSizePoints,
            symbolRect: variantEntry.symbolRect,
            imageURL: pngURL
        )
    }

    private static func loadIndex(bundle: Bundle) -> [Int: SymbolIndexEntry] {
        guard let rootURL = bundle.resourceURL else { return [:] }
        let indexURL = rootURL.appendingPathComponent("USGS/11A02/symbol-index.json")

        guard let data = try? Data(contentsOf: indexURL),
              let document = try? JSONDecoder().decode(SymbolIndexDocument.self, from: data)
        else {
            return [:]
        }

        var map: [Int: SymbolIndexEntry] = [:]
        for entry in document.entries {
            map[entry.code] = entry
        }
        return map
    }
}

private struct SymbolIndexDocument: Codable {
    let entries: [SymbolIndexEntry]
}

private struct SymbolIndexEntry: Codable {
    let code: Int
    let label: String
    let preferredVariant: String
    let fallbackVariant: String
    let epsFile: String
    let symbolRect: USGSSymbolRect
    let ai8: VariantEntry?
    let cs2: VariantEntry?
}

private struct VariantEntry: Codable {
    let code: Int
    let label: String
    let epsFile: String
    let pngFile: String
    let pageSizePoints: CGSizeDTO
    let symbolRect: USGSSymbolRect
    let variant: String
}
