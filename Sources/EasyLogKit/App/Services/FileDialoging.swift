import Foundation

/// Result of the export save panel selection, including destination URL and selected format.
public struct ExportDestinationSelection {
    public let url: URL
    public let format: ExportFormat

    public init(url: URL, format: ExportFormat) {
        self.url = url
        self.format = format
    }
}

@MainActor
/// Abstraction over macOS file panels to keep the view model testable.
public protocol FileDialoging {
    func chooseProjectToOpen() -> URL?
    func chooseProjectToSave() -> URL?
    func chooseExportDestination() -> ExportDestinationSelection?
    func chooseExportDirectory() -> URL?
}

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Default `NSOpenPanel`/`NSSavePanel` implementation used by EasyLogApp.
public struct AppKitFileDialogService: FileDialoging {
    public init() {}

    public func chooseProjectToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "panel.openProject.title", bundle: EasyLogKitBundle.resources)
        panel.message = String(localized: "panel.openProject.message", bundle: EasyLogKitBundle.resources)
        panel.prompt = String(localized: "panel.openProject.prompt", bundle: EasyLogKitBundle.resources)
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseProjectToSave() -> URL? {
        let panel = NSSavePanel()
        panel.title = String(localized: "panel.saveProject.title", bundle: EasyLogKitBundle.resources)
        panel.message = String(localized: "panel.saveProject.message", bundle: EasyLogKitBundle.resources)
        panel.prompt = String(localized: "panel.saveProject.prompt", bundle: EasyLogKitBundle.resources)
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "easylog-project.json"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseExportDestination() -> ExportDestinationSelection? {
        let panel = NSSavePanel()
        panel.title = String(localized: "panel.exportFile.title", bundle: EasyLogKitBundle.resources)
        panel.message = String(localized: "panel.exportFile.message", bundle: EasyLogKitBundle.resources)
        panel.prompt = String(localized: "panel.exportFile.prompt", bundle: EasyLogKitBundle.resources)
        var allowedTypes: [UTType] = [.jpeg]
        if let svg = UTType(filenameExtension: "svg") {
            allowedTypes.insert(svg, at: 0)
        }
        if let csv = UTType(filenameExtension: "csv") {
            allowedTypes.append(csv)
        } else {
            allowedTypes.append(.commaSeparatedText)
        }
        panel.allowedContentTypes = allowedTypes
        panel.nameFieldStringValue = "easylog-export.svg"
        guard panel.runModal() == .OK else { return nil }
        guard let url = panel.url else { return nil }
        return ExportDestinationSelection(url: url, format: Self.exportFormat(for: url))
    }

    public func chooseExportDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "panel.exportDirectory.title", bundle: EasyLogKitBundle.resources)
        panel.message = String(localized: "panel.exportDirectory.message", bundle: EasyLogKitBundle.resources)
        panel.prompt = String(localized: "panel.exportDirectory.prompt", bundle: EasyLogKitBundle.resources)
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func exportFormat(for url: URL) -> ExportFormat {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            return .jpg
        case "csv":
            return .csv
        case "svg":
            return .svg
        default:
            return .svg
        }
    }
}
#else
/// Fallback no-op implementation for non-AppKit targets.
public struct AppKitFileDialogService: FileDialoging {
    public init() {}

    public func chooseProjectToOpen() -> URL? { nil }
    public func chooseProjectToSave() -> URL? { nil }
    public func chooseExportDestination() -> ExportDestinationSelection? { nil }
    public func chooseExportDirectory() -> URL? { nil }
}
#endif
