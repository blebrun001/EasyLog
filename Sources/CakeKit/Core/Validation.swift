import Foundation

/// Validation message surfaced in the sidebar status area.
public struct ValidationIssue: Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

/// Stateless domain validation rules for editable projects.
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
            if !SymbologyLibrary.isSupportedUSGSLithologyCode(unit.usgsLithologyCode) {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                issues.append(
                    ValidationIssue(message: "Unit \(label) uses unsupported USGS lithology code '\(unit.usgsLithologyCode)'.")
                )
            }
        }

        return issues
    }
}
