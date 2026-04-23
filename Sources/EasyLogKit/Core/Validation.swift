import Foundation

public enum ValidationSeverity: String, Codable, Sendable, Hashable {
    case warning
    case error
}

public enum ValidationScope: String, Codable, Sendable, Hashable {
    case project
    case settings
    case unit
}

public struct ValidationReport: Sendable, Hashable {
    public struct Entry: Identifiable, Sendable, Hashable {
        public let id: UUID
        public let severity: ValidationSeverity
        public let code: String
        public let message: String
        public let scope: ValidationScope
        public let unitID: UUID?

        public init(
            id: UUID = UUID(),
            severity: ValidationSeverity,
            code: String,
            message: String,
            scope: ValidationScope,
            unitID: UUID? = nil
        ) {
            self.id = id
            self.severity = severity
            self.code = code
            self.message = message
            self.scope = scope
            self.unitID = unitID
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) {
        self.entries = entries
    }

    public var hasErrors: Bool {
        entries.contains { $0.severity == .error }
    }
}

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
        validateReport(project).entries.map { ValidationIssue(message: $0.message) }
    }

    public static func validateReport(_ project: Project) -> ValidationReport {
        var entries: [ValidationReport.Entry] = []

        if project.units.isEmpty {
            entries.append(
                ValidationReport.Entry(
                    severity: .warning,
                    code: "PROJECT_EMPTY",
                    message: "Project has no units.",
                    scope: .project
                )
            )
        }

        if project.settings.verticalScale <= 0 {
            entries.append(
                ValidationReport.Entry(
                    severity: .error,
                    code: "SETTINGS_VERTICAL_SCALE_NON_POSITIVE",
                    message: "Vertical scale must be greater than 0.",
                    scope: .settings
                )
            )
        }

        if project.settings.baseFontSize <= 0 {
            entries.append(
                ValidationReport.Entry(
                    severity: .error,
                    code: "SETTINGS_FONT_SIZE_NON_POSITIVE",
                    message: "Base font size must be greater than 0.",
                    scope: .settings
                )
            )
        }

        for unit in project.units {
            if unit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                entries.append(
                    ValidationReport.Entry(
                        severity: .warning,
                        code: "UNIT_NAME_EMPTY",
                        message: "A unit has no name.",
                        scope: .unit,
                        unitID: unit.id
                    )
                )
            }
            if unit.thickness <= 0 {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                entries.append(
                    ValidationReport.Entry(
                        severity: .error,
                        code: "UNIT_THICKNESS_NON_POSITIVE",
                        message: String(format: "Unit %1$@ must have thickness > 0.", label),
                        scope: .unit,
                        unitID: unit.id
                    )
                )
            }
            if !SymbologyLibrary.isSupportedUSGSLithologyCode(unit.usgsLithologyCode) {
                let label = unit.name.isEmpty ? "<unnamed>" : unit.name
                entries.append(
                    ValidationReport.Entry(
                        severity: .error,
                        code: "UNIT_UNSUPPORTED_USGS_CODE",
                        message: String(format: "Unit %1$@ uses unsupported USGS lithology code '%2$d'.", label, unit.usgsLithologyCode),
                        scope: .unit,
                        unitID: unit.id
                    )
                )
            }
        }

        return ValidationReport(entries: entries)
    }
}
