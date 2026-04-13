import Foundation

/// Crop rectangle (in source asset points) for a single USGS symbol tile.
public struct USGSSymbolRect: Codable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

/// Fully resolved symbol asset references for one USGS symbol.
public struct USGSSymbolAsset: Hashable {
    public let symbolId: String
    public let code: Int?
    public let label: String
    public let section: String
    public let sourceFileNameUSGS: String
    public let variant: String
    public let epsRelativePath: String
    public let pdfRelativePath: String
    public let isolatedPdfRelativePath: String?
    public let pageSizePoints: CGSizeDTO
    public let symbolRect: USGSSymbolRect
    public let pdfURL: URL
    public let usesIsolatedPDF: Bool
}

/// Loads and caches the generated runtime catalog, then resolves asset URLs.
public final class USGSSymbolAssetResolver: @unchecked Sendable {
    public static let shared = USGSSymbolAssetResolver()

    private let primaryCatalog: USGSResourceCatalog?
    private let fallbackCatalog: USGSResourceCatalog?
    private let assetByCode: [Int: USGSSymbolAsset]

    public init(
        bundle: Bundle = CakeKitBundle.resources,
        profile: USGSResourceProfile = CakeKitBundle.resourceProfile
    ) {
        self.primaryCatalog = try? USGSResourceCatalog(bundle: bundle, profile: profile)
        if profile == .release {
            self.fallbackCatalog = nil
        } else {
            self.fallbackCatalog = try? USGSResourceCatalog(bundle: bundle, profile: .release)
        }
        self.assetByCode = Self.buildAssetIndex(primary: primaryCatalog, fallback: fallbackCatalog)
    }

    public static func asset(for code: Int) -> USGSSymbolAsset? {
        shared.asset(for: code)
    }

    public func asset(for code: Int) -> USGSSymbolAsset? {
        let resolvedCode = SymbologyLibrary.renderableUSGSCode(forSelectionCode: code)
        return assetByCode[resolvedCode]
    }

    private static func makeAsset(entry: USGSResourceCatalog.Entry, pdfURL: URL) -> USGSSymbolAsset {
        let usesIsolatedPDF = entry.isolatedPdfPath != nil && pdfURL.path.contains("/isolated/")
        return USGSSymbolAsset(
            symbolId: entry.symbolId,
            code: entry.code,
            label: entry.label,
            section: entry.section,
            sourceFileNameUSGS: entry.sourceFileNameUSGS,
            variant: entry.variant,
            epsRelativePath: entry.epsRelativePath,
            pdfRelativePath: entry.pdf.path,
            isolatedPdfRelativePath: entry.isolatedPdfPath,
            pageSizePoints: entry.pageSizePoints,
            symbolRect: entry.symbolRect,
            pdfURL: pdfURL,
            usesIsolatedPDF: usesIsolatedPDF
        )
    }

    private static func buildAssetIndex(
        primary: USGSResourceCatalog?,
        fallback: USGSResourceCatalog?
    ) -> [Int: USGSSymbolAsset] {
        struct Candidate {
            let catalog: USGSResourceCatalog
            let entry: USGSResourceCatalog.Entry
            let rank: Int
        }

        let catalogPriority: [(USGSResourceCatalog, Int)] = [
            primary.map { ($0, 0) },
            fallback.map { ($0, 100) }
        ].compactMap { $0 }

        var candidatesByCode: [Int: [Candidate]] = [:]
        for (catalog, baseRank) in catalogPriority {
            for entry in catalog.entries {
                guard let code = entry.code else { continue }
                let variantRank = entry.variant == "ai8" ? 0 : 1
                let rank = baseRank + variantRank
                candidatesByCode[code, default: []].append(
                    Candidate(catalog: catalog, entry: entry, rank: rank)
                )
            }
        }

        var resolved: [Int: USGSSymbolAsset] = [:]
        resolved.reserveCapacity(candidatesByCode.count)
        for (code, candidates) in candidatesByCode {
            for candidate in candidates.sorted(by: { $0.rank < $1.rank }) {
                if let isolatedURL = try? candidate.catalog.resolvedPDFURL(for: candidate.entry, preferIsolated: true) {
                    resolved[code] = Self.makeAsset(entry: candidate.entry, pdfURL: isolatedURL)
                    break
                }

                if let fullURL = try? candidate.catalog.resolvedPDFURL(for: candidate.entry, preferIsolated: false) {
                    resolved[code] = Self.makeAsset(entry: candidate.entry, pdfURL: fullURL)
                    break
                }
            }
        }
        return resolved
    }
}
