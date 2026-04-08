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
func zeroLevelAltitudeRemainsIndependentPerLog() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.project.settings.zeroLevelAltitudeMeters = 123
    viewModel.addLog()
    viewModel.project.settings.zeroLevelAltitudeMeters = 456

    viewModel.selectLog(at: 0)
    #expect(viewModel.project.settings.zeroLevelAltitudeMeters == 123)

    viewModel.selectLog(at: 1)
    #expect(viewModel.project.settings.zeroLevelAltitudeMeters == 456)
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
func availableDetailPanesTracksSyntheticAvailability() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    #expect(viewModel.availableDetailPanes == [.preview])

    viewModel.project.settings.zeroLevelAltitudeMeters = 100
    viewModel.addLog()
    viewModel.project.settings.zeroLevelAltitudeMeters = 104
    #expect(viewModel.availableDetailPanes == [.preview, .synthetic])
}

@MainActor
@Test
func selectingSyntheticPaneFallsBackToPreviewWhenUnavailable() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    #expect(viewModel.selectedDetailPane == .preview)
    viewModel.selectDetailPane(.synthetic)
    #expect(viewModel.selectedDetailPane == .preview)

    viewModel.project.settings.zeroLevelAltitudeMeters = 100
    viewModel.addLog()
    viewModel.project.settings.zeroLevelAltitudeMeters = 110
    viewModel.selectDetailPane(.synthetic)
    #expect(viewModel.selectedDetailPane == .synthetic)

    viewModel.removeCurrentLog()
    #expect(viewModel.selectedDetailPane == .preview)
}

@MainActor
@Test
func canRemoveCurrentLogIsEnabledOnlyForMultiLogDocuments() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    #expect(viewModel.canRemoveCurrentLog == false)
    viewModel.addLog()
    #expect(viewModel.canRemoveCurrentLog == true)
    viewModel.removeCurrentLog()
    #expect(viewModel.canRemoveCurrentLog == false)
}

@MainActor
@Test
func togglingInspectorUpdatesPresentationState() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    #expect(viewModel.isInspectorPresented == false)
    viewModel.toggleInspector()
    #expect(viewModel.isInspectorPresented == true)

    viewModel.setInspectorPresented(false)
    #expect(viewModel.isInspectorPresented == false)
}

@MainActor
@Test
func selectingLogUpdatesStatusMessageWithOneBasedIndex() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.addLog()
    viewModel.selectLog(at: 0)
    #expect(viewModel.statusMessage == "Selected log 1")

    viewModel.selectLog(at: 1)
    #expect(viewModel.statusMessage == "Selected log 2")
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

    viewModel.updateViewportSize(CGSize(width: 720, height: 500))
    viewModel.setManualZoom(1.3)
    viewModel.resetZoom()
    #expect(viewModel.zoomMode == .fitWidth)
    #expect(viewModel.zoom == 720 / viewModel.scene.canvasSize.width)
}

@MainActor
@Test
func defaultZoomModeIsFitWidth() {
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

    #expect(viewModel.zoomMode == .fitWidth)
}

@MainActor
@Test
func firstViewportUpdateAppliesFitWidthImmediatelyByDefault() {
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

    let viewport = CGSize(width: 760, height: 500)
    viewModel.updateViewportSize(viewport)
    #expect(viewModel.zoom > viewport.width / viewModel.scene.canvasSize.width)
}

@MainActor
@Test
func startupIgnoresStalePersistedManualZoomAndUsesFitWidth() {
    let suiteName = "cake-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(1.0, forKey: "cake.viewer.zoom")
    defaults.set("manual", forKey: "cake.viewer.zoomMode")
    defaults.set(false, forKey: "cake.viewer.autoAdjust")

    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService(),
        defaults: defaults
    )

    #expect(viewModel.zoomMode == .fitWidth)
    let viewport = CGSize(width: 760, height: 500)
    viewModel.updateViewportSize(viewport)
    #expect(viewModel.zoom > viewport.width / viewModel.scene.canvasSize.width)
}

@MainActor
@Test
func resetZoomVisibilityTracksManualZoomChanges() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    #expect(viewModel.canResetManualZoom == false)

    viewModel.setZoomMode(.fitWidth)
    #expect(viewModel.canResetManualZoom == false)

    viewModel.setManualZoom(1.6)
    #expect(viewModel.canResetManualZoom == true)

    viewModel.resetZoom()
    #expect(viewModel.canResetManualZoom == false)
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
func fitWidthIsNotLimitedByManualZoomMaximum() {
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

    viewModel.updateViewportSize(CGSize(width: 5000, height: 900))
    viewModel.setZoomMode(.fitWidth)
    #expect(viewModel.zoom > 2.5)
}

@MainActor
@Test
func fitHeightComputesZoomFromViewportHeight() {
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

    let viewport = CGSize(width: 560, height: 330)
    viewModel.updateViewportSize(viewport)
    viewModel.setZoomMode(.fitHeight)

    let expected = viewport.height / viewModel.scene.canvasSize.height
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

@MainActor
@Test
func colorProfilesBootstrapWithSingleDefaultProfile() {
    let suiteName = "cake-vm-preset-tests-\(UUID().uuidString)"
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

    #expect(viewModel.colorProfiles.count == 1)
    #expect(viewModel.activeColorProfileName == "Default")
}

@MainActor
@Test
func colorProfilesPersistAcrossViewModelSessions() {
    let suiteName = "cake-vm-preset-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let viewModelA = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService(),
        defaults: defaults
    )
    viewModelA.createColorProfile(name: "Carbonates")
    viewModelA.setLithologyColorPreset(usgsCode: 627, hex: "#12ab34")

    let viewModelB = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService(),
        defaults: defaults
    )

    #expect(viewModelB.activeColorProfileName == "Carbonates")
    #expect(viewModelB.presetColor(for: 627) == "#12AB34")
}

@MainActor
@Test
func deletingActiveProfileSwitchesToAnotherValidProfile() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.createColorProfile(name: "A")
    let profileToDelete = viewModel.activeColorProfileID
    viewModel.createColorProfile(name: "B")

    if let profileToDelete {
        viewModel.deleteColorProfile(id: profileToDelete)
    }

    #expect(viewModel.colorProfiles.count == 2)
    #expect(viewModel.activeColorProfileID != nil)
    #expect(viewModel.colorProfiles.contains(where: { $0.id == viewModel.activeColorProfileID }))
}

@MainActor
@Test
func applyPresetToSelectedUnitUsesManualMappingOnlyWhenPresent() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    guard let selectedIndex = viewModel.selectedUnitIndex else {
        Issue.record("Expected a selected unit in sample project")
        return
    }

    let code = viewModel.project.units[selectedIndex].usgsLithologyCode
    #expect(viewModel.project.units[selectedIndex].lithologyColorHex == nil)
    viewModel.applyPresetToSelectedUnit()
    #expect(viewModel.project.units[selectedIndex].lithologyColorHex == nil)

    viewModel.setLithologyColorPreset(usgsCode: code, hex: "#445566")
    viewModel.applyPresetToSelectedUnit()
    #expect(viewModel.project.units[selectedIndex].lithologyColorHex == "#445566")
}

@MainActor
@Test
func removingOneLithologyPresetKeepsOtherMappings() {
    let viewModel = ProjectViewModel(
        project: Project.sample,
        store: MockProjectStore(),
        exporter: MockExporter(),
        fileDialogService: MockFileDialogService()
    )

    viewModel.setLithologyColorPreset(usgsCode: 627, hex: "#AA0000")
    viewModel.setLithologyColorPreset(usgsCode: 607, hex: "#00BB00")
    viewModel.removeLithologyColorPreset(usgsCode: 627)

    #expect(viewModel.presetColor(for: 627) == nil)
    #expect(viewModel.presetColor(for: 607) == "#00BB00")
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
