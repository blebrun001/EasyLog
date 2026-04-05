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
    try store.save(ProjectDocument(logs: [source]), to: tempURL)
    let expected = try store.load(url: tempURL)

    let dialogs = MockFileDialogService(openURL: tempURL)
    let viewModel = ProjectViewModel(
        project: Project(),
        store: store,
        exporter: MockExporter(),
        fileDialogService: dialogs
    )

    viewModel.openProjectViaPanel()

    #expect(viewModel.project == expected.logs[0])
    #expect(viewModel.logs.count == 1)
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
    #expect(store.lastSavedDocument?.logs.count == 1)
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
func addAndDuplicateLogSelectNewTabsAndKeepIndependentData() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.addLog()
    #expect(viewModel.logs.count == 2)
    #expect(viewModel.selectedLogIndex == 1)

    viewModel.project.metadata.title = "Secondary"
    viewModel.selectLog(at: 0)
    #expect(viewModel.project.metadata.title == "Example Core Log")

    viewModel.duplicateCurrentLog()
    #expect(viewModel.logs.count == 3)
    #expect(viewModel.selectedLogIndex == 1)
    #expect(viewModel.project.metadata.title == "Example Core Log Copy")
}

@MainActor
@Test
func removeLogKeepsAtLeastOneAndAdjustsSelection() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.addLog()
    viewModel.project.metadata.title = "Second"
    viewModel.addLog()
    viewModel.project.metadata.title = "Third"
    #expect(viewModel.logs.count == 3)
    #expect(viewModel.selectedLogIndex == 2)

    viewModel.removeLog(at: 1)
    #expect(viewModel.logs.count == 2)
    #expect(viewModel.selectedLogIndex == 1)
    #expect(viewModel.project.metadata.title == "Third")

    viewModel.removeLog(at: 0)
    #expect(viewModel.logs.count == 1)
    #expect(viewModel.selectedLogIndex == 0)

    viewModel.removeLog(at: 0)
    #expect(viewModel.logs.count == 1)
    #expect(viewModel.selectedLogIndex == 0)
}

@MainActor
@Test
func syntheticViewRequiresAtLeastTwoLogs() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.project.settings.zeroLevelAltitudeMeters = 100
    #expect(viewModel.logs.count == 1)
    #expect(viewModel.canOpenSyntheticView == false)
}

@MainActor
@Test
func syntheticViewRequiresZeroLevelOnEveryLog() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.project.settings.zeroLevelAltitudeMeters = 100
    viewModel.addLog()
    viewModel.project.settings.zeroLevelAltitudeMeters = nil
    #expect(viewModel.canOpenSyntheticView == false)
}

@MainActor
@Test
func syntheticViewIsEnabledWithTwoLogsAndAllZeroLevelsSet() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.project.settings.zeroLevelAltitudeMeters = 100
    viewModel.addLog()
    viewModel.project.settings.zeroLevelAltitudeMeters = 96
    #expect(viewModel.canOpenSyntheticView == true)
}

@MainActor
@Test
func exportAllProjectsEmitsOneFilePerLogAndResolvesFilenameCollisions() {
    let exporter = MockExporter()
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: exporter,
        fileDialogService: MockFileDialogService()
    )

    viewModel.project.metadata.title = "Same Name"
    viewModel.addLog()
    viewModel.project.metadata.title = "Same Name"

    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "cake-export-all-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    viewModel.exportAllProjects(to: folder, format: .svg, dpi: 300)

    #expect(exporter.requests.count == 2)
    #expect(Set(exporter.requests.map(\.url.lastPathComponent)).count == 2)
    #expect(exporter.requests.allSatisfy { $0.url.pathExtension == "svg" })
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
    var loadResult: ProjectDocument = ProjectDocument(logs: [.sample])
    var lastSavedDocument: ProjectDocument?
    var lastSavedURL: URL?

    func load(url: URL) throws -> ProjectDocument {
        loadResult
    }

    func save(_ document: ProjectDocument, to url: URL) throws {
        lastSavedDocument = document
        lastSavedURL = url
    }
}

private final class MockExporter: Exporter {
    struct Request {
        let scene: RenderScene
        let url: URL
        let format: ExportFormat
        let dpi: Double
    }

    var requests: [Request] = []

    var lastScene: RenderScene? { requests.last?.scene }
    var lastURL: URL? { requests.last?.url }
    var lastFormat: ExportFormat? { requests.last?.format }
    var lastDPI: Double? { requests.last?.dpi }

    func export(scene: RenderScene, to url: URL, options: ExportOptions) throws {
        requests.append(Request(scene: scene, url: url, format: options.format, dpi: options.dpi))
    }
}

private struct MockFileDialogService: FileDialoging {
    var openURL: URL? = nil
    var saveURL: URL? = nil
    var exportURL: URL? = nil
    var exportDirectoryURL: URL? = nil

    func chooseProjectToOpen() -> URL? {
        openURL
    }

    func chooseProjectToSave() -> URL? {
        saveURL
    }

    func chooseExportDestination(format: ExportFormat) -> URL? {
        exportURL
    }

    func chooseExportDirectory() -> URL? {
        exportDirectoryURL
    }
}
