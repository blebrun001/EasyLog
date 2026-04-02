import Foundation
import Testing
@testable import CakeKit

@MainActor
/// Ensures open flow hydrates the view model and clears previous errors.
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

@MainActor
@Test
func zoomCommandsClampToConfiguredBoundsAndReset() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.zoom = 2.48
    viewModel.zoomIn()
    #expect(viewModel.zoom == 2.5)
    viewModel.zoomIn()
    #expect(viewModel.zoom == 2.5)

    viewModel.zoom = 0.52
    viewModel.zoomOut()
    #expect(viewModel.zoom == 0.5)
    viewModel.zoomOut()
    #expect(viewModel.zoom == 0.5)

    viewModel.resetZoom()
    #expect(viewModel.zoom == 1.0)
}

@MainActor
@Test
func fitToWindowComputesZoomFromViewportSize() {
    let suiteName = "cake-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService(),
        defaults: defaults
    )

    let viewport = CGSize(width: 540, height: 420)
    viewModel.updateViewportSize(viewport)
    viewModel.setZoomMode(.fitWindow)

    let expected = min(
        viewport.width / viewModel.scene.canvasSize.width,
        viewport.height / viewModel.scene.canvasSize.height
    )
    #expect(abs(viewModel.zoom - expected) < 0.0001)
}

@MainActor
@Test
func autoAdjustResizesUntilManualZoomSuspendsIt() async throws {
    let suiteName = "cake-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService(),
        defaults: defaults
    )

    viewModel.setZoomMode(.fitWidth)
    viewModel.setAutoAdjustToWindow(true)
    viewModel.updateViewportSize(CGSize(width: 700, height: 500))
    try await Task.sleep(nanoseconds: 180_000_000)

    let fitZoom = viewModel.zoom
    #expect(fitZoom == 700 / viewModel.scene.canvasSize.width)

    viewModel.setManualZoom(1.75)
    viewModel.updateViewportSize(CGSize(width: 300, height: 500))
    try await Task.sleep(nanoseconds: 180_000_000)
    #expect(viewModel.zoom == 1.75)
}

@MainActor
@Test
func moveSelectedUnitCommandsReorderUnits() {
    var project = Project.sample
    project.units = [
        StratigraphicUnit(name: "A", thickness: 1, lithology: "Massive sand or sandstone"),
        StratigraphicUnit(name: "B", thickness: 1, lithology: "Limestone"),
        StratigraphicUnit(name: "C", thickness: 1, lithology: "Sandy or silty shale")
    ]

    let viewModel = ProjectViewModel(
        project: project,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.selectedUnitID = viewModel.project.units[1].id // B
    viewModel.moveSelectedUnitUp()
    #expect(viewModel.project.units.map(\.name) == ["B", "A", "C"])

    viewModel.moveSelectedUnitDown()
    #expect(viewModel.project.units.map(\.name) == ["A", "B", "C"])
}

@MainActor
@Test
func updatingNestedProjectSettingsRefreshesScene() async throws {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    let initialScale = viewModel.scene.symbolScale
    viewModel.project.settings.symbolScale = 1.9

    // Project refresh uses a 33ms debounce.
    try await Task.sleep(nanoseconds: 120_000_000)

    #expect(initialScale != 1.9)
    #expect(viewModel.scene.symbolScale == 1.9)
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
