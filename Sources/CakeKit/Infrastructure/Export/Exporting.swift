import Foundation

/// Supported export formats available from the UI.
public enum ExportFormat: String, CaseIterable, Identifiable {
    case svg
    case jpg

    public var id: String { rawValue }
}

/// Export request options shared across exporter implementations.
public struct ExportOptions {
    public var format: ExportFormat
    public var dpi: Double

    public init(format: ExportFormat, dpi: Double = 300) {
        self.format = format
        self.dpi = dpi
    }
}

/// Generic export facade for scene -> file conversion.
public protocol Exporter {
    func export(scene: RenderScene, to url: URL, options: ExportOptions) throws
}

/// Specialized SVG exporter protocol used by tests and composition.
public protocol SVGExporting {
    func export(scene: RenderScene, to url: URL, canvas: CGSizeDTO) throws
}

/// Routes export requests to the concrete exporter for each format.
public struct CompositeExporter: Exporter {
    private let svgExporter: SVGExporting
    private let jpgExporter: JPGExporter

    public init(svgExporter: SVGExporting = SVGExporter(), jpgExporter: JPGExporter = JPGExporter()) {
        self.svgExporter = svgExporter
        self.jpgExporter = jpgExporter
    }

    public func export(scene: RenderScene, to url: URL, options: ExportOptions) throws {
        switch options.format {
        case .svg:
            try svgExporter.export(scene: scene, to: url, canvas: scene.canvasSize)
        case .jpg:
            try jpgExporter.export(scene: scene, to: url, options: options)
        }
    }
}
