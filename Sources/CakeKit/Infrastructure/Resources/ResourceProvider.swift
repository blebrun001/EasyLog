import Foundation

public protocol ResourceProvider {
    func url(for relativePath: String) throws -> URL
    func data(for relativePath: String) throws -> Data
}

public enum ResourceProviderError: Error, CustomStringConvertible {
    case invalidRoot
    case invalidRelativePath(String)
    case missingFile(String)

    public var description: String {
        switch self {
        case .invalidRoot:
            return "Resource provider root URL is unavailable."
        case .invalidRelativePath(let path):
            return "Invalid relative resource path: \(path)"
        case .missingFile(let path):
            return "Missing resource file: \(path)"
        }
    }
}

public struct BundleResourceProvider: ResourceProvider {
    private let rootURL: URL

    public init(bundle: Bundle = CakeKitBundle.resources) throws {
        guard let rootURL = bundle.resourceURL else {
            throw ResourceProviderError.invalidRoot
        }
        self.rootURL = rootURL
    }

    public func url(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("..") else {
            throw ResourceProviderError.invalidRelativePath(relativePath)
        }

        let url = rootURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ResourceProviderError.missingFile(relativePath)
        }
        return url
    }

    public func data(for relativePath: String) throws -> Data {
        let url = try url(for: relativePath)
        return try Data(contentsOf: url)
    }
}

public struct DirectoryResourceProvider: ResourceProvider {
    private let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func url(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.contains("..") else {
            throw ResourceProviderError.invalidRelativePath(relativePath)
        }

        let url = rootURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ResourceProviderError.missingFile(relativePath)
        }
        return url
    }

    public func data(for relativePath: String) throws -> Data {
        let url = try url(for: relativePath)
        return try Data(contentsOf: url)
    }
}
