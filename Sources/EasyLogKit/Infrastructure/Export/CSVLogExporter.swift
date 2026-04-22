import Foundation

/// Exports one project as a CSV table with one row per stratigraphic unit.
public struct CSVLogExporter: CSVLogExporting {
    private static let separator = ";"
    private static let pointFeatureSeparator = " | "
    private static let headerColumns = [
        "log_title",
        "us_index",
        "us_name",
        "thickness_m",
        "lithology_code",
        "lithology_label",
        "grain_size",
        "point_features_count",
        "point_features_labels"
    ]

    public init() {}

    public func export(project: Project, to url: URL) throws {
        var lines: [String] = []
        lines.append(Self.headerColumns.joined(separator: Self.separator))

        for (index, unit) in project.units.enumerated() {
            let pointFeatureLabels = unit.pointFeatures
                .map { $0.type.label }
                .joined(separator: Self.pointFeatureSeparator)

            let columns = [
                project.metadata.title,
                String(index + 1),
                unit.name,
                String(unit.thickness),
                String(unit.usgsLithologyCode),
                unit.lithologyLabel,
                unit.grainSize?.rawValue ?? "",
                String(unit.pointFeatures.count),
                pointFeatureLabels
            ]

            lines.append(columns.map(Self.escapedField).joined(separator: Self.separator))
        }

        let csv = lines.joined(separator: "\n") + "\n"
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escapedField(_ value: String) -> String {
        guard value.contains(separator) || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
