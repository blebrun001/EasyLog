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
    private let localizer: LocalizationService

    public init(defaults: UserDefaults = .standard) {
        self.localizer = LocalizationService(defaults: defaults, bundle: EasyLogKitBundle.resources)
    }

    public func chooseProjectToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.title = localizer.text("panel.openProject.title")
        panel.message = localizer.text("panel.openProject.message")
        panel.prompt = localizer.text("panel.openProject.prompt")
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseProjectToSave() -> URL? {
        let panel = NSSavePanel()
        panel.title = localizer.text("panel.saveProject.title")
        panel.message = localizer.text("panel.saveProject.message")
        panel.prompt = localizer.text("panel.saveProject.prompt")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "easylog-project.json"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseExportDestination() -> ExportDestinationSelection? {
        let panel = NSSavePanel()
        panel.title = localizer.text("panel.exportFile.title")
        panel.message = localizer.text("panel.exportFile.message")
        panel.prompt = localizer.text("panel.exportFile.prompt")
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
        panel.title = localizer.text("panel.exportDirectory.title")
        panel.message = localizer.text("panel.exportDirectory.message")
        panel.prompt = localizer.text("panel.exportDirectory.prompt")
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
