import Foundation

/// Service focused on document-level operations (create/open/save).
public struct ProjectDocumentService {
    private let persister: any ProjectPersisting
    private let now: () -> Date

    public init(persister: any ProjectPersisting, now: @escaping () -> Date = Date.init) {
        self.persister = persister
        self.now = now
    }

    public func newDocument() -> ProjectDocument {
        ProjectDocument(logs: [Project()])
    }

    public func open(url: URL) throws -> ProjectDocument {
        try persister.load(url: url)
    }

    public func save(_ document: ProjectDocument, to url: URL) throws -> ProjectDocument {
        var updated = document
        updated.logs = updated.logs.map { log in
            var copy = log
            copy.metadata.updatedAt = now()
            return copy
        }
        try persister.save(updated, to: url)
        return updated
    }
}
