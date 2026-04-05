import Foundation

/// Persistence contract for loading/saving complete project documents.
public protocol ProjectStore {
    func load(url: URL) throws -> ProjectDocument
    func save(_ document: ProjectDocument, to url: URL) throws
}

/// Errors raised by project persistence adapters.
public enum ProjectStoreError: LocalizedError {
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid or unreadable project file."
        }
    }
}

/// JSON-backed project store using ISO8601 date encoding.
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

    public func load(url: URL) throws -> ProjectDocument {
        let data = try Data(contentsOf: url)
        do {
            return try decoder.decode(ProjectDocument.self, from: data)
        } catch {
            do {
                let legacyProject = try decoder.decode(Project.self, from: data)
                return ProjectDocument(logs: [legacyProject])
            } catch {
                throw ProjectStoreError.invalidData
            }
        }
    }

    public func save(_ document: ProjectDocument, to url: URL) throws {
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }
}
