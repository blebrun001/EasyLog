import CryptoKit
import Foundation

public enum USGSResourceProfile: String, Codable {
    case dev
    case release
}

public struct USGSResourceCatalog {
    public struct AssetFile: Codable, Hashable {
        public let path: String
        public let sha256: String
        public let bytes: Int
    }

    public struct Entry: Codable, Hashable {
        public let id: String
        public let symbolId: String
        public let code: Int?
        public let label: String
        public let section: String
        public let sourceFileNameUSGS: String
        public let variant: String
        public let epsRelativePath: String
        public let pageSizePoints: CGSizeDTO
        public let symbolRect: USGSSymbolRect
        public let isolatedPdfPath: String?
        public let pdf: AssetFile
    }

    private struct Document: Codable {
        let schemaVersion: Int
        let profile: String
        let sourceIndex: String
        let totalEntries: Int
        let generatedBy: String
        let entries: [Entry]
    }

    public enum CatalogError: Error, CustomStringConvertible {
        case invalidManifest(String)
        case missingEntryForCode(Int)
        case missingAsset(String)
        case hashMismatch(path: String, expected: String, actual: String)

        public var description: String {
            switch self {
            case .invalidManifest(let reason):
                return "Invalid resource catalog: \(reason)"
            case .missingEntryForCode(let code):
                return "No resource entry found for USGS code \(code)."
            case .missingAsset(let path):
                return "Catalog references a missing asset: \(path)."
            case .hashMismatch(let path, let expected, let actual):
                return "Asset hash mismatch for \(path): expected \(expected), got \(actual)."
            }
        }
    }

    public let profile: USGSResourceProfile
    public let entries: [Entry]

    private let provider: any ResourceProvider
    private let entriesByCode: [Int: [Entry]]

    public init(
        bundle: Bundle = EasyLogKitBundle.resources,
        profile: USGSResourceProfile = EasyLogKitBundle.resourceProfile
    ) throws {
        self.profile = profile
        self.provider = try BundleResourceProvider(bundle: bundle)
        let relativePath = "USGSRuntime/ResourceCatalog.\(profile.rawValue).json"
        let data = try provider.data(for: relativePath)
        let document = try JSONDecoder().decode(Document.self, from: data)
        try Self.validate(document: document)
        self.entries = document.entries
        self.entriesByCode = Self.buildByCode(entries: entries)
    }

    public init(profile: USGSResourceProfile, provider: any ResourceProvider, manifestData: Data) throws {
        self.profile = profile
        self.provider = provider
        let document = try JSONDecoder().decode(Document.self, from: manifestData)
        try Self.validate(document: document)
        self.entries = document.entries
        self.entriesByCode = Self.buildByCode(entries: entries)
    }

    public func preferredEntry(forCode code: Int) throws -> Entry {
        guard let candidates = entriesByCode[code], !candidates.isEmpty else {
            throw CatalogError.missingEntryForCode(code)
        }
        if let ai8 = candidates.first(where: { $0.variant == "ai8" }) {
            return ai8
        }
        return candidates[0]
    }

    public func resolvedPDFURL(for entry: Entry, validateHashes: Bool = false, preferIsolated: Bool = true) throws -> URL {
        let relativePath = (preferIsolated ? entry.isolatedPdfPath : nil) ?? entry.pdf.path
        let pdfURL = try provider.url(for: relativePath)

        if validateHashes {
            let pdfData = try Data(contentsOf: pdfURL)
            let pdfDigest = SHA256.hash(data: pdfData).hexString
            if pdfDigest != entry.pdf.sha256 {
                throw CatalogError.hashMismatch(path: relativePath, expected: entry.pdf.sha256, actual: pdfDigest)
            }
        }
        return pdfURL
    }

    private static func validate(document: Document) throws {
        guard document.schemaVersion == 2 else {
            throw CatalogError.invalidManifest("Unsupported schema version \(document.schemaVersion)")
        }
    }

    private static func buildByCode(entries: [Entry]) -> [Int: [Entry]] {
        var map: [Int: [Entry]] = [:]
        for entry in entries {
            guard let code = entry.code else { continue }
            map[code, default: []].append(entry)
        }
        return map
    }

}

private extension SHA256Digest {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
