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
        public let code: Int
        public let label: String
        public let variant: String
        public let epsRelativePath: String
        public let pageSizePoints: CGSizeDTO
        public let symbolRect: USGSSymbolRect
        public let png: AssetFile
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
        case missingEntry(code: Int)
        case missingAsset(path: String)
        case hashMismatch(path: String, expected: String, actual: String)

        public var description: String {
            switch self {
            case .invalidManifest(let reason):
                return "Invalid resource catalog: \(reason)"
            case .missingEntry(let code):
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
        bundle: Bundle = CakeKitBundle.resources,
        profile: USGSResourceProfile = CakeKitBundle.resourceProfile
    ) throws {
        self.profile = profile
        self.provider = try BundleResourceProvider(bundle: bundle)
        let relativePath = "USGSRuntime/ResourceCatalog.\(profile.rawValue).json"
        let data = try provider.data(for: relativePath)
        let document = try JSONDecoder().decode(Document.self, from: data)

        guard document.schemaVersion == 1 else {
            throw CatalogError.invalidManifest("Unsupported schema version \(document.schemaVersion)")
        }

        self.entries = document.entries
        var map: [Int: [Entry]] = [:]
        for entry in entries {
            map[entry.code, default: []].append(entry)
        }
        self.entriesByCode = map
    }

    public init(profile: USGSResourceProfile, provider: any ResourceProvider, manifestData: Data) throws {
        self.profile = profile
        self.provider = provider
        let document = try JSONDecoder().decode(Document.self, from: manifestData)
        guard document.schemaVersion == 1 else {
            throw CatalogError.invalidManifest("Unsupported schema version \(document.schemaVersion)")
        }
        self.entries = document.entries

        var map: [Int: [Entry]] = [:]
        for entry in entries {
            map[entry.code, default: []].append(entry)
        }
        self.entriesByCode = map
    }

    public func preferredEntry(for code: Int) throws -> Entry {
        guard let candidates = entriesByCode[code], !candidates.isEmpty else {
            throw CatalogError.missingEntry(code: code)
        }

        if let ai8 = candidates.first(where: { $0.variant == "ai8" }) {
            return ai8
        }
        return candidates[0]
    }

    public func resolvedURLs(for entry: Entry, validateHashes: Bool = false) throws -> (pngURL: URL, pdfURL: URL) {
        let pngURL = try provider.url(for: entry.png.path)
        let pdfURL = try provider.url(for: entry.pdf.path)

        if validateHashes {
            let pngData = try Data(contentsOf: pngURL)
            let pdfData = try Data(contentsOf: pdfURL)

            let pngDigest = SHA256.hash(data: pngData).hexString
            let pdfDigest = SHA256.hash(data: pdfData).hexString

            if pngDigest != entry.png.sha256 {
                throw CatalogError.hashMismatch(path: entry.png.path, expected: entry.png.sha256, actual: pngDigest)
            }
            if pdfDigest != entry.pdf.sha256 {
                throw CatalogError.hashMismatch(path: entry.pdf.path, expected: entry.pdf.sha256, actual: pdfDigest)
            }
        }

        return (pngURL, pdfURL)
    }
}

private extension SHA256Digest {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}
