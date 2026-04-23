import Foundation

/// Exports one project as a CSV table with one row per stratigraphic unit.
public struct CSVLogExporter: CSVLogExporting {
    private static let separator = ";"
    private static let listSeparator = "|"
    private static let headerColumns = [
        "project_title",
        "project_author",
        "project_created_at_utc",
        "project_updated_at_utc",
        "unit_uuid",
        "unit_index_1_based",
        "unit_name",
        "thickness_m",
        "depth_top_m",
        "depth_base_m",
        "lithology_code",
        "lithology_label",
        "lithology_color_hex",
        "grain_size_code",
        "grain_size_label",
        "point_features_count",
        "point_features_type_codes",
        "point_features_labels",
        "point_features_category_codes",
        "point_features_category_labels",
        "point_features_densities",
        "point_features_color_hexes"
    ]

    public init() {}

    public func export(project: Project, to url: URL) throws {
        var lines: [String] = []
        lines.append(Self.headerColumns.joined(separator: Self.separator))

        let createdAt = Self.formattedDateUTC(project.metadata.createdAt)
        let updatedAt = Self.formattedDateUTC(project.metadata.updatedAt)
        var cumulativeDepth = 0.0

        for (index, unit) in project.units.enumerated() {
            let depthTop = cumulativeDepth
            let depthBase = cumulativeDepth + unit.thickness
            cumulativeDepth = depthBase

            let pointFeatureTypeCodes = unit.pointFeatures
                .map { $0.type.rawValue }
                .joined(separator: Self.listSeparator)
            let pointFeatureLabels = unit.pointFeatures
                .map { $0.type.label }
                .joined(separator: Self.listSeparator)
            let pointFeatureCategoryCodes = unit.pointFeatures
                .map { $0.type.category.rawValue }
                .joined(separator: Self.listSeparator)
            let pointFeatureCategoryLabels = unit.pointFeatures
                .map { $0.type.categoryLabel }
                .joined(separator: Self.listSeparator)
            let pointFeatureDensities = unit.pointFeatures
                .map { Self.formattedNumber($0.density) }
                .joined(separator: Self.listSeparator)
            let pointFeatureColorHexes = unit.pointFeatures
                .map(\.resolvedColorHex)
                .joined(separator: Self.listSeparator)

            let columns = [
                project.metadata.title,
                project.metadata.author,
                createdAt,
                updatedAt,
                unit.id.uuidString.lowercased(),
                String(index + 1),
                unit.name,
                Self.formattedNumber(unit.thickness),
                Self.formattedNumber(depthTop),
                Self.formattedNumber(depthBase),
                String(unit.usgsLithologyCode),
                unit.lithologyLabel,
                unit.lithologyColorHex ?? "",
                unit.grainSize?.rawValue ?? "",
                unit.grainSize?.label ?? "",
                String(unit.pointFeatures.count),
                pointFeatureTypeCodes,
                pointFeatureLabels,
                pointFeatureCategoryCodes,
                pointFeatureCategoryLabels,
                pointFeatureDensities,
                pointFeatureColorHexes
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

    private static func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = "."
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 12
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static func formattedDateUTC(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
