import Foundation

/// Service focused on export orchestration.
public struct ExportService {
    private let exporter: any Exporting

    public init(exporter: any Exporting) {
        self.exporter = exporter
    }

    public func export(scene: RenderScene, to url: URL, format: ExportFormat, dpi: Double) throws {
        try exporter.export(scene: scene, to: url, options: ExportOptions(format: format, dpi: dpi))
    }
}
