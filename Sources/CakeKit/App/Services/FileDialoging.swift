import Foundation

@MainActor
/// Abstraction over macOS file panels to keep the view model testable.
public protocol FileDialoging {
    func chooseProjectToOpen() -> URL?
    func chooseProjectToSave() -> URL?
    func chooseExportDestination(format: ExportFormat) -> URL?
}

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Default `NSOpenPanel`/`NSSavePanel` implementation used by CakeApp.
public struct AppKitFileDialogService: FileDialoging {
    public init() {}

    public func chooseProjectToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseProjectToSave() -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "cake-project.json"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    public func chooseExportDestination(format: ExportFormat) -> URL? {
        let panel = NSSavePanel()
        switch format {
        case .svg:
            if let svg = UTType(filenameExtension: "svg") {
                panel.allowedContentTypes = [svg]
            }
            panel.nameFieldStringValue = "cake-export.svg"
        case .jpg:
            panel.allowedContentTypes = [.jpeg]
            panel.nameFieldStringValue = "cake-export.jpg"
        }
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
#else
/// Fallback no-op implementation for non-AppKit targets.
public struct AppKitFileDialogService: FileDialoging {
    public init() {}

    public func chooseProjectToOpen() -> URL? { nil }
    public func chooseProjectToSave() -> URL? { nil }
    public func chooseExportDestination(format _: ExportFormat) -> URL? { nil }
}
#endif
