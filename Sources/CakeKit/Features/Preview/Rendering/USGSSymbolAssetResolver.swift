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
}

/// Loads and caches the generated runtime catalog, then resolves asset URLs.
public final class USGSSymbolAssetResolver: @unchecked Sendable {
    public static let shared = USGSSymbolAssetResolver()

    private let primaryCatalog: USGSResourceCatalog?
    private let fallbackCatalog: USGSResourceCatalog?

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
    }

    public static func asset(for code: Int) -> USGSSymbolAsset? {
        shared.asset(for: code)
    }

    public static func asset(forSymbolID symbolID: String) -> USGSSymbolAsset? {
        shared.asset(forSymbolID: symbolID)
    }

    public static func allSections() -> [String] {
        shared.allSections()
    }

    public static func symbols(inSection section: String) -> [USGSSymbolAsset] {
        shared.symbols(inSection: section)
    }

    public static func searchSymbols(labelContains query: String) -> [USGSSymbolAsset] {
        shared.searchSymbols(labelContains: query)
    }

    public func asset(for code: Int) -> USGSSymbolAsset? {
        let resolvedCode = SymbologyLibrary.renderableUSGSCode(forSelectionCode: code)
        for catalog in catalogs {
            guard let entry = try? catalog.preferredEntry(forCode: resolvedCode),
                  let url = try? catalog.resolvedPDFURL(for: entry) else {
                continue
            }
            return makeAsset(entry: entry, pdfURL: url)
        }
        return nil
    }

    public func asset(forSymbolID symbolID: String) -> USGSSymbolAsset? {
        for catalog in catalogs {
            guard let entry = try? catalog.preferredEntry(forSymbolID: symbolID),
                  let url = try? catalog.resolvedPDFURL(for: entry) else {
                continue
            }
            return makeAsset(entry: entry, pdfURL: url)
        }
        return nil
    }

    public func allSections() -> [String] {
        var sections: [String] = []
        for catalog in catalogs {
            sections.append(contentsOf: catalog.allSections())
        }
        return Array(Set(sections)).sorted()
    }

    public func symbols(inSection section: String) -> [USGSSymbolAsset] {
        var assets: [USGSSymbolAsset] = []
        var seen = Set<String>()
        for catalog in catalogs {
            for entry in catalog.entries(inSection: section) {
                guard seen.insert(entry.symbolId).inserted else { continue }
                guard let url = try? catalog.resolvedPDFURL(for: entry) else { continue }
                assets.append(makeAsset(entry: entry, pdfURL: url))
            }
        }
        return assets.sorted {
            if $0.label != $1.label {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.symbolId < $1.symbolId
        }
    }

    public func searchSymbols(labelContains query: String) -> [USGSSymbolAsset] {
        var assets: [USGSSymbolAsset] = []
        var seen = Set<String>()
        for catalog in catalogs {
            for entry in catalog.search(labelContains: query) {
                guard seen.insert(entry.symbolId).inserted else { continue }
                guard let url = try? catalog.resolvedPDFURL(for: entry) else { continue }
                assets.append(makeAsset(entry: entry, pdfURL: url))
            }
        }
        return assets.sorted {
            if $0.label != $1.label {
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
            return $0.symbolId < $1.symbolId
        }
    }

    private var catalogs: [USGSResourceCatalog] {
        [primaryCatalog, fallbackCatalog].compactMap { $0 }
    }

    private func makeAsset(entry: USGSResourceCatalog.Entry, pdfURL: URL) -> USGSSymbolAsset {
        USGSSymbolAsset(
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
            pdfURL: pdfURL
        )
    }
}
