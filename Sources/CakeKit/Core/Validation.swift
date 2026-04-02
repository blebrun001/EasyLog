import Foundation

public struct ValidationIssue: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

public enum ProjectValidator {
    public static func validate(_ project: Project) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        for unit in project.units {
            if unit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(ValidationIssue(message: "A unit has no name."))
            }
            if unit.thickness <= 0 {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                issues.append(ValidationIssue(message: "Unit \(label) must have thickness > 0."))
            }
            if unit.lithology.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                issues.append(ValidationIssue(message: "Unit \(label) must define lithology."))
            } else if !SymbologyLibrary.isSupportedLithology(unit.lithology) {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                issues.append(ValidationIssue(message: "Unit \(label) uses unsupported lithology '\(unit.lithology)'."))
            }
        }

        return issues
    }
}
