import Foundation

public protocol ProjectStore {
    func load(url: URL) throws -> Project
    func save(_ project: Project, to url: URL) throws
}

public enum ProjectStoreError: LocalizedError {
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid or unreadable project file."
        }
    }
}

public struct JSONProjectStore: ProjectStore {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = encoder
        self.decoder = decoder
    }

    public func load(url: URL) throws -> Project {
        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(Project.self, from: data)
        } catch {
            throw ProjectStoreError.invalidData
        }
    }

    public func save(_ project: Project, to url: URL) throws {
        let data = try encoder.encode(project)
        try data.write(to: url, options: .atomic)
    }
}
