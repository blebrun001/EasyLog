import Foundation
import Testing
@testable import CakeKit

@MainActor
@Test
func openProjectViaDialogLoadsProjectAndUpdatesState() throws {
    let store = JSONProjectStore()
    let source = Project.sample
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-open-\(UUID().uuidString).json")
    try store.save(source, to: tempURL)
    let expected = try store.load(url: tempURL)

    let dialogs = MockFileDialogService(openURL: tempURL)
    let viewModel = ProjectViewModel(
        project: Project(),
        store: store,
        exporter: MockExporter(),
        fileDialogService: dialogs
    )

    viewModel.openProjectViaPanel()

    #expect(viewModel.project == expected)
    #expect(viewModel.projectURL == tempURL)
}

@MainActor
@Test
func saveProjectWritesToStoreAndTracksURL() {
    let store = MockProjectStore()
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: store,
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )
    let saveURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-save-\(UUID().uuidString).json")

    viewModel.saveProject(at: saveURL)

    #expect(store.lastSavedURL == saveURL)
    #expect(viewModel.projectURL == saveURL)
}

@MainActor
@Test
func exportProjectPassesRequestedFormatAndDPI() {
    let exporter = MockExporter()
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: exporter,
        fileDialogService: MockFileDialogService()
    )
    let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-export-\(UUID().uuidString).jpg")

    viewModel.exportProject(to: exportURL, format: .jpg, dpi: 240)

    #expect(exporter.lastURL == exportURL)
    #expect(exporter.lastFormat == .jpg)
    #expect(exporter.lastDPI == 240)
}

private final class MockProjectStore: ProjectStore {
    var loadResult: Project = .sample
    var lastSavedProject: Project?
    var lastSavedURL: URL?

    func load(url: URL) throws -> Project {
        loadResult
    }

    func save(_ project: Project, to url: URL) throws {
        lastSavedProject = project
        lastSavedURL = url
    }
}

private final class MockExporter: Exporter {
    var lastScene: RenderScene?
    var lastURL: URL?
    var lastFormat: ExportFormat?
    var lastDPI: Double?

    func export(scene: RenderScene, to url: URL, options: ExportOptions) throws {
        lastScene = scene
        lastURL = url
        lastFormat = options.format
        lastDPI = options.dpi
    }
}

private struct MockFileDialogService: FileDialoging {
    var openURL: URL? = nil
    var saveURL: URL? = nil
    var exportURL: URL? = nil

    func chooseProjectToOpen() -> URL? {
        openURL
    }

    func chooseProjectToSave() -> URL? {
        saveURL
    }

    func chooseExportDestination(format: ExportFormat) -> URL? {
        exportURL
    }
}
