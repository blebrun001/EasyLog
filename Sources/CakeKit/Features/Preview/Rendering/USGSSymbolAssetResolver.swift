import Foundation

/// Crop rectangle (in source asset points) for a single USGS symbol tile.
public struct USGSSymbolRect: Codable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

/// Fully resolved symbol asset references for one USGS code.
public struct USGSSymbolAsset: Hashable {
    public let code: Int
    public let label: String
    public let variant: String
    public let epsRelativePath: String
    public let pngRelativePath: String
    public let pdfRelativePath: String
    public let pageSizePoints: CGSizeDTO
    public let symbolRect: USGSSymbolRect
    public let pdfURL: URL
    public let imageURL: URL
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

    public func asset(for code: Int) -> USGSSymbolAsset? {
        let resolvedCode = SymbologyLibrary.renderableUSGSCode(forSelectionCode: code)

        for catalog in [primaryCatalog, fallbackCatalog].compactMap({ $0 }) {
            guard let entry = try? catalog.preferredEntry(for: resolvedCode),
                  let urls = try? catalog.resolvedURLs(for: entry) else {
                continue
            }

            return USGSSymbolAsset(
                code: code,
                label: entry.label,
                variant: entry.variant,
                epsRelativePath: entry.epsRelativePath,
                pngRelativePath: entry.png.path,
                pdfRelativePath: entry.pdf.path,
                pageSizePoints: entry.pageSizePoints,
                symbolRect: entry.symbolRect,
                pdfURL: urls.pdfURL,
                imageURL: urls.pngURL
            )
        }
        return nil
    }

}
