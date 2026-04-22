import AppKit
import Combine
import CoreGraphics
import Foundation
import os

public enum EasyLogPreferencesKey {
    public static let showsInspectorOnLaunch = "easylog.preferences.showsInspectorOnLaunch"
    public static let defaultDetailPane = "easylog.preferences.defaultDetailPane"
}

private struct ProjectStoreAdapter: ProjectPersisting {
    let store: any ProjectStore

    func load(url: URL) throws -> ProjectDocument { try store.load(url: url) }
    func save(_ document: ProjectDocument, to url: URL) throws { try store.save(document, to: url) }
}

@MainActor
internal final class SceneOrchestrator {
    private let stateStore: ProjectViewModelStateStore
    private let context: ProjectViewModelContext

    init(stateStore: ProjectViewModelStateStore, context: ProjectViewModelContext) {
        self.stateStore = stateStore
        self.context = context
    }

    func refreshScene() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        vm.scheduleSceneRefresh(trigger: .structural)
    }

    func selectDetailPane(_ pane: EditorPresentationState.DetailPane) {
        let vm = stateStore.viewModel
        let targetPane: EditorPresentationState.DetailPane =
            (pane == .synthetic && !vm.canOpenSyntheticView) ? .preview : pane
        guard vm.presentationState.selectedDetailPane != targetPane else { return }
        vm.presentationState.selectedDetailPane = targetPane
    }

    func toggleInspector() {
        stateStore.viewModel.presentationState.isInspectorPresented.toggle()
    }

    func setInspectorPresented(_ isPresented: Bool) {
        stateStore.viewModel.presentationState.isInspectorPresented = isPresented
    }
}

@MainActor
internal final class ZoomOrchestrator {
    private let stateStore: ProjectViewModelStateStore
    private let context: ProjectViewModelContext

    init(stateStore: ProjectViewModelStateStore, context: ProjectViewModelContext) {
        self.stateStore = stateStore
        self.context = context
    }

    func zoomIn() {
        let vm = stateStore.viewModel
        setManualZoom(vm.zoom + 0.1, isInteracting: false)
        vm.statusMessage = "Zoom \(Int((vm.zoom * 100).rounded()))%"
    }

    func zoomOut() {
        let vm = stateStore.viewModel
        setManualZoom(vm.zoom - 0.1, isInteracting: false)
        vm.statusMessage = "Zoom \(Int((vm.zoom * 100).rounded()))%"
    }

    func fitToWindow() {
        let vm = stateStore.viewModel
        setZoomMode(.fitWindow)
        vm.statusMessage = "Zoom fit window"
    }

    func resetZoom() {
        let vm = stateStore.viewModel
        vm.hasManualZoomOverride = false
        setZoomMode(.fitWindow)
        vm.statusMessage = "Zoom fit window"
    }

    func setManualZoom(_ value: Double, isInteracting: Bool) {
        let vm = stateStore.viewModel
        let clamped = context.zoomService.clampedZoom(value, tuning: context.tuning)
        let didChange = abs(clamped - vm.zoom) > 0.0001
        vm.zoom = clamped

        guard didChange else { return }
        vm.isManualZoomInteractionActive = isInteracting
        vm.hasManualZoomOverride = true

        if vm.autoAdjustToWindow, vm.zoomMode != .manual {
            vm.isAutoAdjustSuspendedByManualZoom = true
            if !isInteracting {
                vm.scheduleRasterizationForCurrentZoom()
            }
            return
        }

        vm.zoomMode = .manual
        if !isInteracting {
            vm.scheduleRasterizationForCurrentZoom()
        }
    }

    func finalizeManualZoomInteraction() {
        let vm = stateStore.viewModel
        guard vm.isManualZoomInteractionActive else { return }
        vm.isManualZoomInteractionActive = false
        vm.scheduleRasterizationForCurrentZoom()
    }

    func setZoomMode(_ mode: ProjectViewModel.ZoomMode) {
        let vm = stateStore.viewModel
        vm.zoomMode = mode

        guard mode != .manual else { return }
        vm.hasManualZoomOverride = false
        vm.isAutoAdjustSuspendedByManualZoom = false
        vm.applyFit(mode: mode)
    }

    func setAutoAdjustToWindow(_ enabled: Bool) {
        let vm = stateStore.viewModel
        vm.autoAdjustToWindow = enabled

        if enabled {
            vm.hasManualZoomOverride = false
            vm.isAutoAdjustSuspendedByManualZoom = false
            vm.applyAutoAdjustIfNeeded()
        }
    }

    func updateViewportSize(_ size: CGSize) {
        let vm = stateStore.viewModel
        let normalized = CGSize(width: max(0, size.width), height: max(0, size.height))
        guard normalized != vm.viewportSize else { return }
        let hadViewport = vm.viewportSize.width > 0 && vm.viewportSize.height > 0
        #if DEBUG
        context.zoomLogger.debug(
            "updateViewportSize raw=(\(size.width, format: .fixed(precision: 2)), \(size.height, format: .fixed(precision: 2))) normalized=(\(normalized.width, format: .fixed(precision: 2)), \(normalized.height, format: .fixed(precision: 2))) oldViewport=(\(vm.viewportSize.width, format: .fixed(precision: 2)), \(vm.viewportSize.height, format: .fixed(precision: 2))) mode=\(vm.zoomMode.rawValue, privacy: .public) zoom=\(vm.zoom, format: .fixed(precision: 4)) autoAdjust=\(vm.autoAdjustToWindow) manualOverride=\(vm.hasManualZoomOverride)"
        )
        #endif
        vm.viewportSize = normalized

        if !vm.didApplyInitialWindowFit, vm.viewportSize.width > 0 {
            vm.didApplyInitialWindowFit = true
            vm.hasManualZoomOverride = false
            vm.isAutoAdjustSuspendedByManualZoom = false
            if vm.zoomMode == .manual {
                vm.zoomMode = .fitWindow
            }
            vm.applyFit(mode: vm.zoomMode)
            #if DEBUG
            context.zoomLogger.debug(
                "initial auto-fit forced mode=\(vm.zoomMode.rawValue, privacy: .public) -> zoom=\(vm.zoom, format: .fixed(precision: 4)) viewport=(\(vm.viewportSize.width, format: .fixed(precision: 2)), \(vm.viewportSize.height, format: .fixed(precision: 2))) canvas=(\(vm.scene.canvasSize.width, format: .fixed(precision: 2)), \(vm.scene.canvasSize.height, format: .fixed(precision: 2)))"
            )
            #endif
            return
        }

        if !hadViewport {
            vm.applyAutoAdjustIfNeeded()
            return
        }

        vm.scheduleAutoAdjust()
    }
}

@MainActor
internal final class ProjectDocumentOrchestrator {
    private let stateStore: ProjectViewModelStateStore
    private let context: ProjectViewModelContext

    init(stateStore: ProjectViewModelStateStore, context: ProjectViewModelContext) {
        self.stateStore = stateStore
        self.context = context
    }

    func selectLog(at index: Int) {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        vm.commitCurrentProjectChanges()
        vm.setSelectedLog(index)
        vm.statusMessage = "Selected log \(index + 1)"
    }

    func addLog() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        vm.commitCurrentProjectChanges()
        vm.document.logs.append(Project())
        vm.setSelectedLog(vm.document.logs.count - 1)
        vm.presentationState.selectedDetailPane = .preview
        vm.statusMessage = "Added new log"
    }

    func duplicateCurrentLog() {
        let vm = stateStore.viewModel
        guard vm.document.logs.indices.contains(vm.selectedLogIndex) else { return }
        vm.setNextSceneRefreshTrigger(.structural)
        vm.commitCurrentProjectChanges()

        var duplicated = vm.document.logs[vm.selectedLogIndex]
        let existingTitles = vm.document.logs.map { $0.metadata.title }
        duplicated.metadata.title = vm.duplicatedLogTitle(for: duplicated.metadata.title, existingTitles: existingTitles)

        let insertIndex = vm.selectedLogIndex + 1
        vm.document.logs.insert(duplicated, at: insertIndex)
        vm.setSelectedLog(insertIndex)
        vm.presentationState.selectedDetailPane = .preview
        vm.statusMessage = "Duplicated current log"
    }

    func removeLog(at index: Int) {
        let vm = stateStore.viewModel
        guard vm.document.logs.indices.contains(index) else { return }
        guard vm.document.logs.count > 1 else { return }
        vm.setNextSceneRefreshTrigger(.structural)
        vm.commitCurrentProjectChanges()

        vm.document.logs.remove(at: index)

        let nextIndex: Int
        if vm.selectedLogIndex > index {
            nextIndex = vm.selectedLogIndex - 1
        } else if vm.selectedLogIndex == index {
            nextIndex = min(index, vm.document.logs.count - 1)
        } else {
            nextIndex = vm.selectedLogIndex
        }

        vm.setSelectedLog(nextIndex)
        if !vm.canOpenSyntheticView {
            vm.presentationState.selectedDetailPane = .preview
        }
        vm.statusMessage = "Removed log \(index + 1)"
    }

    func removeCurrentLog() {
        let vm = stateStore.viewModel
        removeLog(at: vm.selectedLogIndex)
    }

    func addUnit() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        vm.selectedUnitID = context.addUnitUseCase.execute(project: &vm.project)
    }

    func removeSelectedUnit() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        vm.selectedUnitID = context.deleteSelectedUnitUseCase.execute(project: &vm.project, selectedUnitID: vm.selectedUnitID)
    }

    func moveUnits(fromOffsets source: IndexSet, toOffset destination: Int) {
        let vm = stateStore.viewModel
        guard !source.isEmpty else { return }
        vm.setNextSceneRefreshTrigger(.structural)

        let movedUnits = source.map { vm.project.units[$0] }
        for index in source.sorted(by: >) {
            vm.project.units.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        vm.project.units.insert(contentsOf: movedUnits, at: adjustedDestination)
        vm.statusMessage = "Reordered units"
    }

    func moveSelectedUnitUp() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        let before = vm.selectedUnitID
        context.moveSelectedUnitUseCase.execute(project: &vm.project, selectedUnitID: vm.selectedUnitID, direction: .up)
        guard let current = vm.selectedUnitID else { return }
        if before == current, vm.project.units.first?.id != current {
            vm.statusMessage = "Moved selected unit up"
        }
    }

    func moveSelectedUnitDown() {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(.structural)
        let before = vm.selectedUnitID
        context.moveSelectedUnitUseCase.execute(project: &vm.project, selectedUnitID: vm.selectedUnitID, direction: .down)
        guard let current = vm.selectedUnitID else { return }
        if before == current, vm.project.units.last?.id != current {
            vm.statusMessage = "Moved selected unit down"
        }
    }

    func updateProjectSettings(_ newSettings: ProjectSettings, trigger: SceneRefreshTrigger) {
        let vm = stateStore.viewModel
        vm.setNextSceneRefreshTrigger(trigger)
        var updatedProject = vm.project
        updatedProject.settings = newSettings
        vm.project = updatedProject
    }

    func newProject() {
        let vm = stateStore.viewModel
        vm.flushPendingColorPresetPersistence()
        vm.setNextSceneRefreshTrigger(.structural)
        vm.document = ProjectDocument(logs: [Project()])
        vm.setSelectedLog(0)
        vm.projectURL = nil
        vm.presentationState = EditorPresentationState()
        vm.isAutoAdjustSuspendedByManualZoom = false
        vm.hasManualZoomOverride = false
        vm.statusMessage = "New project"
        vm.errorMessage = nil
    }

    func openProjectViaPanel() {
        guard let url = context.fileDialogService.chooseProjectToOpen() else { return }
        openProject(at: url)
    }

    func saveProjectViaPanelIfNeeded() {
        let vm = stateStore.viewModel
        if let existingURL = vm.projectURL {
            saveProject(at: existingURL)
            return
        }
        guard let url = context.fileDialogService.chooseProjectToSave() else { return }
        saveProject(at: url)
    }

    func openProject(at url: URL) {
        let vm = stateStore.viewModel
        do {
            vm.flushPendingColorPresetPersistence()
            vm.setNextSceneRefreshTrigger(.structural)
            let loaded = try context.documentService.open(url: url)
            vm.document = ProjectDocument(logs: loaded.logs)
            vm.projectURL = url
            vm.setSelectedLog(0)
            vm.presentationState.selectedDetailPane = .preview
            vm.isAutoAdjustSuspendedByManualZoom = false
            vm.hasManualZoomOverride = false
            vm.statusMessage = "Opened \(url.lastPathComponent)"
            vm.errorMessage = nil
        } catch {
            vm.errorMessage = "Could not open project: \(error.localizedDescription). Check that the JSON file is valid and try again."
        }
    }

    func saveProject(at url: URL) {
        let vm = stateStore.viewModel
        do {
            vm.flushPendingColorPresetPersistence()
            vm.commitCurrentProjectChanges()
            let saved = try context.documentService.save(vm.document, to: url)
            vm.document = saved
            vm.setSelectedLog(min(vm.selectedLogIndex, max(saved.logs.count - 1, 0)))
            vm.projectURL = url
            vm.statusMessage = "Saved \(url.lastPathComponent)"
            vm.errorMessage = nil
        } catch {
            vm.errorMessage = "Could not save project: \(error.localizedDescription). Verify write permissions and try again."
        }
    }
}

@MainActor
internal final class ExportOrchestrator {
    private let stateStore: ProjectViewModelStateStore
    private let context: ProjectViewModelContext

    init(stateStore: ProjectViewModelStateStore, context: ProjectViewModelContext) {
        self.stateStore = stateStore
        self.context = context
    }

    func exportViaPanel(format: ExportFormat, dpi: Double) {
        guard let url = context.fileDialogService.chooseExportDestination(format: format) else { return }
        exportProject(to: url, format: format, dpi: dpi)
    }

    func exportAllViaPanel(format: ExportFormat, dpi: Double) {
        guard let directoryURL = context.fileDialogService.chooseExportDirectory() else { return }
        exportAllProjects(to: directoryURL, format: format, dpi: dpi)
    }

    func exportProject(to url: URL, format: ExportFormat, dpi: Double) {
        let vm = stateStore.viewModel
        do {
            try context.exportService.export(scene: vm.scene, to: url, format: format, dpi: dpi)
            vm.statusMessage = "Exported \(url.lastPathComponent)"
            vm.errorMessage = nil
        } catch {
            vm.errorMessage = "Could not export file: \(error.localizedDescription). Choose a writable location and retry."
        }
    }

    func exportAllProjects(to directoryURL: URL, format: ExportFormat, dpi: Double) {
        let vm = stateStore.viewModel
        vm.commitCurrentProjectChanges()

        var successCount = 0
        var failureDetails: [String] = []
        var reservedFilenames = Set<String>()

        for (index, log) in vm.document.logs.enumerated() {
            let scene = context.renderer.makeScene(project: log)
            let basename = vm.preferredExportBaseName(for: log.metadata.title, index: index)
            let destinationURL = vm.uniqueExportURL(
                in: directoryURL,
                basename: basename,
                format: format,
                reservedNames: &reservedFilenames
            )

            do {
                try context.exportService.export(scene: scene, to: destinationURL, format: format, dpi: dpi)
                successCount += 1
            } catch {
                failureDetails.append("\(destinationURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        let total = vm.document.logs.count
        if successCount == 0 {
            vm.errorMessage = "Could not export any logs. \(failureDetails.first ?? "Choose a writable location and retry.")"
            return
        }

        if failureDetails.isEmpty {
            vm.statusMessage = "Exported \(successCount) logs to \(directoryURL.lastPathComponent)"
        } else {
            vm.statusMessage = "Exported \(successCount)/\(total) logs to \(directoryURL.lastPathComponent)"
        }
        vm.errorMessage = nil
    }
}

@MainActor
internal final class ColorPresetOrchestrator {
    private let stateStore: ProjectViewModelStateStore
    private let context: ProjectViewModelContext

    init(stateStore: ProjectViewModelStateStore, context: ProjectViewModelContext) {
        self.stateStore = stateStore
        self.context = context
    }

    func clearError() {
        stateStore.viewModel.errorMessage = nil
    }

    func flushPendingColorPresetPersistence() {
        let vm = stateStore.viewModel
        vm.colorPresetPersistTask?.cancel()
        vm.persistColorPresetStateNow()
    }

    func createColorProfile(name: String) {
        let vm = stateStore.viewModel
        let resolved = context.colorProfileService.uniqueProfileName(
            base: LithologyColorProfile.normalizedName(name),
            existingProfiles: vm.colorProfiles
        )
        let profile = LithologyColorProfile(name: resolved)
        vm.colorProfiles.append(profile)
        vm.activeColorProfileID = profile.id
        vm.persistColorPresetState()
    }

    func renameColorProfile(id: UUID, name: String) {
        let vm = stateStore.viewModel
        guard let index = vm.colorProfiles.firstIndex(where: { $0.id == id }) else { return }
        let resolved = context.colorProfileService.uniqueProfileName(
            base: LithologyColorProfile.normalizedName(name, fallback: vm.colorProfiles[index].name),
            existingProfiles: vm.colorProfiles,
            excludingID: id
        )
        vm.colorProfiles[index].name = resolved
        vm.persistColorPresetState()
    }

    func deleteColorProfile(id: UUID) {
        let vm = stateStore.viewModel
        guard vm.colorProfiles.count > 1 else { return }
        guard let index = vm.colorProfiles.firstIndex(where: { $0.id == id }) else { return }

        vm.colorProfiles.remove(at: index)
        if vm.activeColorProfileID == id {
            vm.activeColorProfileID = vm.colorProfiles.first?.id
        }
        vm.persistColorPresetState()
    }

    func setActiveColorProfile(id: UUID) {
        let vm = stateStore.viewModel
        guard vm.colorProfiles.contains(where: { $0.id == id }) else { return }
        vm.activeColorProfileID = id
        vm.persistColorPresetState()
    }

    func setLithologyColorPreset(usgsCode: Int, hex: String) {
        let vm = stateStore.viewModel
        guard let normalized = LithologyColorProfile.normalizedHex(hex) else { return }
        vm.mutateActiveColorProfile { profile in
            profile.mappings[usgsCode] = normalized
        }
    }

    func removeLithologyColorPreset(usgsCode: Int) {
        let vm = stateStore.viewModel
        vm.mutateActiveColorProfile { profile in
            profile.mappings.removeValue(forKey: usgsCode)
        }
    }

    func presetColor(for usgsCode: Int) -> String? {
        stateStore.viewModel.activeColorProfile?.mappings[usgsCode]
    }

    func applyPresetToSelectedUnit() {
        let vm = stateStore.viewModel
        guard let selectedUnitIndex = vm.selectedUnitIndex else { return }
        let usgsCode = vm.project.units[selectedUnitIndex].usgsLithologyCode
        guard let presetHex = presetColor(for: usgsCode) else { return }
        vm.setNextSceneRefreshTrigger(.structural)
        vm.project.units[selectedUnitIndex].lithologyColorHex = presetHex
        vm.statusMessage = "Applied profile color to selected unit"
    }
}

private struct ExporterAdapter: Exporting {
    let exporter: any Exporter

    func export(scene: RenderScene, to url: URL, options: ExportOptions) throws {
        try exporter.export(scene: scene, to: url, options: options)
    }
}

internal struct ProjectViewModelContext {
    let renderer: LogRenderer
    let documentService: ProjectDocumentService
    let exportService: ExportService
    let fileDialogService: FileDialoging
    let addUnitUseCase: AddUnitUseCase
    let deleteSelectedUnitUseCase: DeleteSelectedUnitUseCase
    let moveSelectedUnitUseCase: MoveSelectedUnitUseCase
    let zoomService: ZoomService
    let colorProfileService: ColorProfileService
    let colorPresetStore: any LithologyColorPresetPersisting
    let sceneRefreshService: SceneRefreshService
    let sceneComputationService: SceneComputationService
    let rasterCache: SceneRasterCache
    let tuning: RenderTuning
    let zoomLogger: Logger
    let perfSignposter: OSSignposter
}

@MainActor
internal final class ProjectViewModelStateStore {
    fileprivate unowned let viewModel: ProjectViewModel

    init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }
}

/// UI-only state shared across menus, toolbar and top-level content views.
public struct EditorPresentationState: Equatable, Sendable {
    public enum DetailPane: String, CaseIterable, Identifiable, Sendable {
        case preview
        case synthetic

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .preview: "Single Log"
            case .synthetic: "Synthetic"
            }
        }
    }

    public var selectedDetailPane: DetailPane
    public var isInspectorPresented: Bool

    public init(
        selectedDetailPane: DetailPane = .preview,
        isInspectorPresented: Bool = false
    ) {
        self.selectedDetailPane = selectedDetailPane
        self.isInspectorPresented = isInspectorPresented
    }
}

@MainActor
/// UI-facing state holder orchestrating project editing, rendering, I/O and export.
public final class ProjectViewModel: ObservableObject {
    public enum ZoomMode: String, CaseIterable, Identifiable {
        case manual
        case fitWindow
        case fitWidth
        case fitHeight

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .manual: "Manual"
            case .fitWindow: "Fit Window"
            case .fitWidth: "Fit Width"
            case .fitHeight: "Fit Height"
            }
        }
    }

    @Published public fileprivate(set) var document: ProjectDocument
    @Published public var project: Project {
        didSet {
            commitCurrentProjectChanges(using: project)
            scheduleSceneRefresh(trigger: consumePendingSceneRefreshTrigger(default: .textInput))
        }
    }
    @Published public fileprivate(set) var selectedLogIndex: Int
    @Published public fileprivate(set) var scene: RenderScene
    @Published public fileprivate(set) var syntheticScene: SyntheticComparisonScene
    @Published public var selectedUnitID: UUID?
    @Published public fileprivate(set) var validationIssues: [ValidationIssue] = []
    @Published public var zoom: Double
    @Published public fileprivate(set) var zoomMode: ZoomMode
    @Published public fileprivate(set) var autoAdjustToWindow: Bool
    @Published public fileprivate(set) var presentationState = EditorPresentationState()
    @Published public fileprivate(set) var statusMessage: String = "Ready"
    @Published public fileprivate(set) var errorMessage: String?
    @Published public fileprivate(set) var colorProfiles: [LithologyColorProfile] = []
    @Published public fileprivate(set) var activeColorProfileID: UUID?
    @Published public fileprivate(set) var showsInspectorOnLaunchPreference: Bool
    @Published public fileprivate(set) var defaultDetailPanePreference: EditorPresentationState.DetailPane
    @Published public fileprivate(set) var editorState: EditorState
    @Published public fileprivate(set) var previewState: PreviewState

    public fileprivate(set) var projectURL: URL?
    public var activeColorProfileName: String {
        activeColorProfile?.name ?? ""
    }

    public var logs: [Project] { document.logs }
    public var selectedDetailPane: EditorPresentationState.DetailPane {
        presentationState.selectedDetailPane
    }
    public var isInspectorPresented: Bool {
        presentationState.isInspectorPresented
    }
    public var availableDetailPanes: [EditorPresentationState.DetailPane] {
        canOpenSyntheticView ? [.preview, .synthetic] : [.preview]
    }
    public var canOpenSyntheticView: Bool {
        sceneRefreshService.canOpenSynthetic(logs: logsApplyingCurrentEdits())
    }
    public var canRemoveCurrentLog: Bool {
        document.logs.count > 1
    }
    public var canResetManualZoom: Bool {
        hasManualZoomOverride
    }

    fileprivate let renderer: LogRenderer
    fileprivate let documentService: ProjectDocumentService
    fileprivate let exportService: ExportService
    fileprivate let fileDialogService: FileDialoging
    fileprivate let addUnitUseCase = AddUnitUseCase()
    fileprivate let deleteSelectedUnitUseCase = DeleteSelectedUnitUseCase()
    fileprivate let moveSelectedUnitUseCase = MoveSelectedUnitUseCase()
    fileprivate let zoomService = ZoomService()
    fileprivate let colorProfileService = ColorProfileService()
    fileprivate let colorPresetStore: any LithologyColorPresetPersisting
    fileprivate let sceneRefreshService = SceneRefreshService()
    fileprivate let sceneComputationService: SceneComputationService
    fileprivate let rasterCache: SceneRasterCache
    fileprivate let tuning: RenderTuning
    fileprivate let userDefaults: UserDefaults
    fileprivate var cancellables = Set<AnyCancellable>()
    fileprivate var viewportSize: CGSize = .zero
    fileprivate var isAutoAdjustSuspendedByManualZoom = false
    fileprivate var hasManualZoomOverride = false
    fileprivate var didApplyInitialWindowFit = false
    fileprivate var sceneRefreshTask: Task<Void, Never>?
    fileprivate var sceneRefreshGeneration: UInt64 = 0
    fileprivate var pendingSceneRefreshTrigger: SceneRefreshTrigger = .textInput
    fileprivate var resizeDebounceTask: Task<Void, Never>?
    fileprivate var previewRasterTask: Task<Void, Never>?
    fileprivate var syntheticRasterTask: Task<Void, Never>?
    fileprivate var colorPresetPersistTask: Task<Void, Never>?
    fileprivate var isManualZoomInteractionActive = false
    fileprivate let zoomLogger = Logger(subsystem: "EasyLog", category: "Zoom")
    fileprivate let perfSignposter = OSSignposter(subsystem: "EasyLog", category: "Perf")
    fileprivate let context: ProjectViewModelContext
    fileprivate lazy var stateStore = ProjectViewModelStateStore(viewModel: self)
    fileprivate lazy var projectDocumentOrchestrator = ProjectDocumentOrchestrator(stateStore: stateStore, context: context)
    fileprivate lazy var sceneOrchestrator = SceneOrchestrator(stateStore: stateStore, context: context)
    fileprivate lazy var zoomOrchestrator = ZoomOrchestrator(stateStore: stateStore, context: context)
    fileprivate lazy var exportOrchestrator = ExportOrchestrator(stateStore: stateStore, context: context)
    fileprivate lazy var colorPresetOrchestrator = ColorPresetOrchestrator(stateStore: stateStore, context: context)

    public init(
        project: Project = .sample,
        renderer: LogRenderer = EasyLogRenderer(),
        store: ProjectStore = JSONProjectStore(),
        exporter: Exporter = CompositeExporter(),
        fileDialogService: FileDialoging = AppKitFileDialogService(),
        defaults: UserDefaults = .standard,
        colorPresetStore: (any LithologyColorPresetPersisting)? = nil,
        tuning: RenderTuning = .default,
        sceneComputationService: SceneComputationService? = nil,
        rasterCache: SceneRasterCache? = nil
    ) {
        let initialPresentationState = Self.initialPresentationState(from: defaults)
        let initialDocument = ProjectDocument(logs: [project])
        let initialSelectedUnitID = project.units.first?.id
        let initialScene = renderer.makeScene(project: project)
        self.project = project
        self.document = initialDocument
        self.selectedLogIndex = 0
        self.renderer = renderer
        self.documentService = ProjectDocumentService(persister: ProjectStoreAdapter(store: store))
        self.exportService = ExportService(exporter: ExporterAdapter(exporter: exporter))
        self.fileDialogService = fileDialogService
        self.colorPresetStore = colorPresetStore ?? UserDefaultsLithologyColorPresetStore(defaults: defaults)
        self.tuning = tuning
        // Launch defaults are always window-fitted to avoid opening in a stale manual zoom
        // state when the zoom-mode selector is hidden from the UI.
        self.zoom = tuning.defaultZoom
        self.zoomMode = .fitWindow
        self.autoAdjustToWindow = true
        self.scene = initialScene
        self.syntheticScene = .empty
        self.selectedUnitID = initialSelectedUnitID
        self.presentationState = initialPresentationState
        self.showsInspectorOnLaunchPreference = initialPresentationState.isInspectorPresented
        self.defaultDetailPanePreference = initialPresentationState.selectedDetailPane
        self.userDefaults = defaults
        self.sceneComputationService = sceneComputationService ?? SceneComputationService(renderer: renderer)
        self.rasterCache = rasterCache ?? SceneRasterCache(maxBytes: tuning.rasterCacheMaxBytes)
        self.context = ProjectViewModelContext(
            renderer: renderer,
            documentService: self.documentService,
            exportService: self.exportService,
            fileDialogService: fileDialogService,
            addUnitUseCase: self.addUnitUseCase,
            deleteSelectedUnitUseCase: self.deleteSelectedUnitUseCase,
            moveSelectedUnitUseCase: self.moveSelectedUnitUseCase,
            zoomService: self.zoomService,
            colorProfileService: self.colorProfileService,
            colorPresetStore: self.colorPresetStore,
            sceneRefreshService: self.sceneRefreshService,
            sceneComputationService: self.sceneComputationService,
            rasterCache: self.rasterCache,
            tuning: tuning,
            zoomLogger: self.zoomLogger,
            perfSignposter: self.perfSignposter
        )
        self.editorState = EditorState(
            document: initialDocument,
            project: project,
            selectedLogIndex: 0,
            selectedUnitID: initialSelectedUnitID,
            presentationState: initialPresentationState,
            statusMessage: "Ready",
            errorMessage: nil
        )
        self.previewState = PreviewState(
            scene: initialScene,
            syntheticScene: .empty,
            validationIssues: [],
            zoom: tuning.defaultZoom,
            zoomMode: .fitWindow,
            isSyntheticAvailable: false,
            previewRasterScale: Double(NSScreen.main?.backingScaleFactor ?? 2),
            syntheticRasterScale: Double(NSScreen.main?.backingScaleFactor ?? 2)
        )
        loadColorPresetState()
        configureStateMirrors()

        setNextSceneRefreshTrigger(.structural)
        scheduleSceneRefresh(trigger: .structural)
    }

    public var selectedUnitIndex: Int? {
        guard let selectedUnitID else { return nil }
        return project.units.firstIndex(where: { $0.id == selectedUnitID })
    }

    public func refreshScene() {
        sceneOrchestrator.refreshScene()
    }

    public func makeSyntheticComparisonScene() -> SyntheticComparisonScene {
        syntheticScene
    }

    public func selectLog(at index: Int) {
        projectDocumentOrchestrator.selectLog(at: index)
    }

    public func addLog() {
        projectDocumentOrchestrator.addLog()
    }

    public func duplicateCurrentLog() {
        projectDocumentOrchestrator.duplicateCurrentLog()
    }

    public func removeLog(at index: Int) {
        projectDocumentOrchestrator.removeLog(at: index)
    }

    public func removeCurrentLog() {
        projectDocumentOrchestrator.removeCurrentLog()
    }

    public func addUnit() {
        projectDocumentOrchestrator.addUnit()
    }

    public func removeSelectedUnit() {
        projectDocumentOrchestrator.removeSelectedUnit()
    }

    public func moveUnits(fromOffsets source: IndexSet, toOffset destination: Int) {
        projectDocumentOrchestrator.moveUnits(fromOffsets: source, toOffset: destination)
    }

    public func moveSelectedUnitUp() {
        projectDocumentOrchestrator.moveSelectedUnitUp()
    }

    public func moveSelectedUnitDown() {
        projectDocumentOrchestrator.moveSelectedUnitDown()
    }

    public func zoomIn() {
        zoomOrchestrator.zoomIn()
    }

    public func zoomOut() {
        zoomOrchestrator.zoomOut()
    }

    public func fitToWindow() {
        zoomOrchestrator.fitToWindow()
    }

    public func resetZoom() {
        zoomOrchestrator.resetZoom()
    }

    public func setManualZoom(_ value: Double, isInteracting: Bool = false) {
        zoomOrchestrator.setManualZoom(value, isInteracting: isInteracting)
    }

    public func finalizeManualZoomInteraction() {
        zoomOrchestrator.finalizeManualZoomInteraction()
    }

    public func setZoomMode(_ mode: ZoomMode) {
        zoomOrchestrator.setZoomMode(mode)
    }

    public func updateProjectSettings(_ newSettings: ProjectSettings, trigger: SceneRefreshTrigger = .slider) {
        projectDocumentOrchestrator.updateProjectSettings(newSettings, trigger: trigger)
    }

    public func selectDetailPane(_ pane: EditorPresentationState.DetailPane) {
        sceneOrchestrator.selectDetailPane(pane)
    }

    public func toggleInspector() {
        sceneOrchestrator.toggleInspector()
    }

    public func setInspectorPresented(_ isPresented: Bool) {
        sceneOrchestrator.setInspectorPresented(isPresented)
    }

    public func setShowsInspectorOnLaunchPreference(_ isEnabled: Bool) {
        showsInspectorOnLaunchPreference = isEnabled
        userDefaults.set(isEnabled, forKey: EasyLogPreferencesKey.showsInspectorOnLaunch)
        setInspectorPresented(isEnabled)
    }

    public func setDefaultDetailPanePreference(_ pane: EditorPresentationState.DetailPane) {
        defaultDetailPanePreference = pane
        userDefaults.set(pane.rawValue, forKey: EasyLogPreferencesKey.defaultDetailPane)
        selectDetailPane(pane)
    }

    public func setAutoAdjustToWindow(_ enabled: Bool) {
        zoomOrchestrator.setAutoAdjustToWindow(enabled)
    }

    public func updateViewportSize(_ size: CGSize) {
        zoomOrchestrator.updateViewportSize(size)
    }

    public func newProject() {
        projectDocumentOrchestrator.newProject()
    }

    public func openProjectViaPanel() {
        projectDocumentOrchestrator.openProjectViaPanel()
    }

    public func saveProjectViaPanelIfNeeded() {
        projectDocumentOrchestrator.saveProjectViaPanelIfNeeded()
    }

    public func exportViaPanel(format: ExportFormat, dpi: Double = 300) {
        exportOrchestrator.exportViaPanel(format: format, dpi: dpi)
    }

    public func exportAllViaPanel(format: ExportFormat, dpi: Double = 300) {
        exportOrchestrator.exportAllViaPanel(format: format, dpi: dpi)
    }

    public func clearError() {
        colorPresetOrchestrator.clearError()
    }

    public func flushPendingColorPresetPersistence() {
        colorPresetOrchestrator.flushPendingColorPresetPersistence()
    }

    public func createColorProfile(name: String) {
        colorPresetOrchestrator.createColorProfile(name: name)
    }

    public func renameColorProfile(id: UUID, name: String) {
        colorPresetOrchestrator.renameColorProfile(id: id, name: name)
    }

    public func deleteColorProfile(id: UUID) {
        colorPresetOrchestrator.deleteColorProfile(id: id)
    }

    public func setActiveColorProfile(id: UUID) {
        colorPresetOrchestrator.setActiveColorProfile(id: id)
    }

    public func setLithologyColorPreset(usgsCode: Int, hex: String) {
        colorPresetOrchestrator.setLithologyColorPreset(usgsCode: usgsCode, hex: hex)
    }

    public func removeLithologyColorPreset(usgsCode: Int) {
        colorPresetOrchestrator.removeLithologyColorPreset(usgsCode: usgsCode)
    }

    public func presetColor(for usgsCode: Int) -> String? {
        colorPresetOrchestrator.presetColor(for: usgsCode)
    }

    public func applyPresetToSelectedUnit() {
        colorPresetOrchestrator.applyPresetToSelectedUnit()
    }

    public func openProject(at url: URL) {
        projectDocumentOrchestrator.openProject(at: url)
    }

    public func saveProject(at url: URL) {
        projectDocumentOrchestrator.saveProject(at: url)
    }

    public func exportProject(to url: URL, format: ExportFormat, dpi: Double = 300) {
        exportOrchestrator.exportProject(to: url, format: format, dpi: dpi)
    }

    public func exportAllProjects(to directoryURL: URL, format: ExportFormat, dpi: Double = 300) {
        exportOrchestrator.exportAllProjects(to: directoryURL, format: format, dpi: dpi)
    }

    deinit {
        sceneRefreshTask?.cancel()
        resizeDebounceTask?.cancel()
        previewRasterTask?.cancel()
        syntheticRasterTask?.cancel()
        colorPresetPersistTask?.cancel()
    }

    fileprivate func configureStateMirrors() {
        $document
            .sink { [weak self] in self?.editorState.document = $0 }
            .store(in: &cancellables)
        $project
            .sink { [weak self] in self?.editorState.project = $0 }
            .store(in: &cancellables)
        $selectedLogIndex
            .sink { [weak self] in self?.editorState.selectedLogIndex = $0 }
            .store(in: &cancellables)
        $selectedUnitID
            .sink { [weak self] in self?.editorState.selectedUnitID = $0 }
            .store(in: &cancellables)
        $presentationState
            .sink { [weak self] in self?.editorState.presentationState = $0 }
            .store(in: &cancellables)
        $statusMessage
            .sink { [weak self] in self?.editorState.statusMessage = $0 }
            .store(in: &cancellables)
        $errorMessage
            .sink { [weak self] in self?.editorState.errorMessage = $0 }
            .store(in: &cancellables)

        $scene
            .sink { [weak self] in self?.previewState.scene = $0 }
            .store(in: &cancellables)
        $syntheticScene
            .sink { [weak self] in self?.previewState.syntheticScene = $0 }
            .store(in: &cancellables)
        $validationIssues
            .sink { [weak self] in self?.previewState.validationIssues = $0 }
            .store(in: &cancellables)
        $zoom
            .sink { [weak self] in self?.previewState.zoom = $0 }
            .store(in: &cancellables)
        $zoomMode
            .sink { [weak self] in self?.previewState.zoomMode = $0 }
            .store(in: &cancellables)
        Publishers.CombineLatest3($project, $document, $selectedLogIndex)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.previewState.isSyntheticAvailable = self.canOpenSyntheticView
            }
            .store(in: &cancellables)
    }

    fileprivate func setNextSceneRefreshTrigger(_ trigger: SceneRefreshTrigger) {
        pendingSceneRefreshTrigger = sceneRefreshService.mergedTrigger(
            current: pendingSceneRefreshTrigger,
            incoming: trigger
        )
    }

    fileprivate func consumePendingSceneRefreshTrigger(default fallback: SceneRefreshTrigger) -> SceneRefreshTrigger {
        let trigger = pendingSceneRefreshTrigger
        pendingSceneRefreshTrigger = fallback
        return trigger
    }

    fileprivate func scheduleSceneRefresh(trigger: SceneRefreshTrigger) {
        sceneRefreshTask?.cancel()
        sceneRefreshGeneration &+= 1
        let generation = sceneRefreshGeneration
        let snapshotProject = project
        let snapshotLogs = logsApplyingCurrentEdits()
        let snapshotSelectedLogIndex = selectedLogIndex
        let shouldComputeSynthetic = sceneRefreshService.canOpenSynthetic(logs: snapshotLogs)
        let debounce = trigger.debounceNanoseconds
        let signpostID = perfSignposter.makeSignpostID()

        sceneRefreshTask = Task { [weak self] in
            guard let self else { return }
            if debounce > 0 {
                try? await Task.sleep(nanoseconds: debounce)
            }
            guard !Task.isCancelled else { return }

            let intervalState = self.perfSignposter.beginInterval("SceneCompute", id: signpostID)
            let sceneResult = await self.sceneComputationService.computeScene(project: snapshotProject)
            let synthetic: SyntheticComparisonScene
            if shouldComputeSynthetic {
                synthetic = await self.sceneComputationService.computeSynthetic(
                    logs: snapshotLogs,
                    selectedLogIndex: snapshotSelectedLogIndex
                )
            } else {
                synthetic = .empty
            }
            self.perfSignposter.endInterval("SceneCompute", intervalState)

            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard generation == self.sceneRefreshGeneration else { return }
                self.scene = sceneResult.scene
                self.validationIssues = sceneResult.validationIssues
                self.syntheticScene = synthetic
                self.previewState.isSyntheticAvailable = shouldComputeSynthetic
                if !shouldComputeSynthetic, self.presentationState.selectedDetailPane == .synthetic {
                    self.presentationState.selectedDetailPane = .preview
                }
                self.applyAutoAdjustIfNeeded()
                var symbolsToWarm = Set(sceneResult.visibleUSGSCodes)
                if shouldComputeSynthetic {
                    for column in synthetic.columns {
                        for unit in column.units {
                            if let code = unit.usgsSymbolCode {
                                symbolsToWarm.insert(code)
                            }
                        }
                    }
                }
                USGSEPSSymbolRenderer.prewarm(codes: Array(symbolsToWarm))
                self.schedulePreviewRasterization(for: sceneResult.scene)
                if shouldComputeSynthetic {
                    self.scheduleSyntheticRasterization(for: synthetic)
                } else {
                    self.syntheticRasterTask?.cancel()
                    self.previewState.syntheticStaticRaster = nil
                    self.previewState.syntheticOverlayRaster = nil
                }
            }
        }
    }

    fileprivate func schedulePreviewRasterization(for scene: RenderScene) {
        previewRasterTask?.cancel()
        let sceneHash = scene.hashValue
        let renderScale = resolvedRenderScale()
        let renderScaleHundredths = quantizedRenderScaleHundredths(renderScale)
        let actualRenderScale = Double(renderScaleHundredths) / 100.0
        let staticKey = SceneRasterKey(
            sceneHash: sceneHash,
            renderScaleHundredths: renderScaleHundredths,
            layer: .static,
            mode: .preview
        )
        let overlayKey = SceneRasterKey(
            sceneHash: sceneHash,
            renderScaleHundredths: renderScaleHundredths,
            layer: .overlay,
            mode: .preview
        )

        previewRasterTask = Task { [weak self] in
            guard let self else { return }
            let staticImage = await self.rasterImage(for: staticKey, canvas: scene.canvasSize) { context in
                SceneCGRenderer.drawStaticLayer(scene: scene, in: context)
            }
            let overlayImage = await self.rasterImage(for: overlayKey, canvas: scene.canvasSize) { context in
                SceneCGRenderer.drawOverlayLayer(scene: scene, in: context)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.scene.hashValue == sceneHash else { return }
                self.previewState.previewStaticRaster = staticImage
                self.previewState.previewOverlayRaster = overlayImage
                self.previewState.previewRasterScale = actualRenderScale
            }
        }
    }

    fileprivate func scheduleSyntheticRasterization(for scene: SyntheticComparisonScene) {
        syntheticRasterTask?.cancel()
        let sceneHash = scene.hashValue
        let renderScale = resolvedRenderScale()
        let renderScaleHundredths = quantizedRenderScaleHundredths(renderScale)
        let actualRenderScale = Double(renderScaleHundredths) / 100.0
        let staticKey = SceneRasterKey(
            sceneHash: sceneHash,
            renderScaleHundredths: renderScaleHundredths,
            layer: .static,
            mode: .synthetic
        )
        let overlayKey = SceneRasterKey(
            sceneHash: sceneHash,
            renderScaleHundredths: renderScaleHundredths,
            layer: .overlay,
            mode: .synthetic
        )

        syntheticRasterTask = Task { [weak self] in
            guard let self else { return }
            let staticImage = await self.rasterImage(for: staticKey, canvas: scene.canvasSize) { context in
                SyntheticSceneCGRenderer.drawStaticLayer(scene: scene, in: context)
            }
            let overlayImage = await self.rasterImage(for: overlayKey, canvas: scene.canvasSize) { context in
                SyntheticSceneCGRenderer.drawOverlayLayer(scene: scene, in: context)
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard self.syntheticScene.hashValue == sceneHash else { return }
                self.previewState.syntheticStaticRaster = staticImage
                self.previewState.syntheticOverlayRaster = overlayImage
                self.previewState.syntheticRasterScale = actualRenderScale
            }
        }
    }

    fileprivate func rasterImage(
        for key: SceneRasterKey,
        canvas: CGSizeDTO,
        renderer: @escaping @Sendable (CGContext) -> Void
    ) async -> CGImage? {
        if let cached = await rasterCache.image(for: key) {
            return cached
        }
        guard let rendered = Self.renderRasterImage(
            canvas: canvas,
            renderScale: Double(key.renderScaleHundredths) / 100.0,
            renderer: renderer
        ) else {
            return nil
        }
        await rasterCache.insert(rendered, for: key)
        return rendered
    }

    fileprivate static func renderRasterImage(
        canvas: CGSizeDTO,
        renderScale: Double,
        renderer: @escaping @Sendable (CGContext) -> Void
    ) -> CGImage? {
        let width = max(Int(canvas.width * renderScale), 1)
        let height = max(Int(canvas.height * renderScale), 1)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }
        context.scaleBy(x: CGFloat(renderScale), y: CGFloat(renderScale))
        // Bitmap CGContext uses a different Y-axis orientation than SwiftUI Canvas.
        // Flip once so cached rasters match live Canvas rendering.
        context.translateBy(x: 0, y: CGFloat(canvas.height))
        context.scaleBy(x: 1, y: -1)
        renderer(context)
        return context.makeImage()
    }

    fileprivate func scheduleRasterizationForCurrentZoom() {
        schedulePreviewRasterization(for: scene)
        if canOpenSyntheticView {
            scheduleSyntheticRasterization(for: syntheticScene)
        }
    }

    fileprivate func resolvedRenderScale() -> Double {
        let backingScale = max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        return zoomService.resolvedRenderScale(backingScale: backingScale, zoom: zoom, tuning: tuning)
    }

    fileprivate func quantizedRenderScaleHundredths(_ value: Double) -> Int {
        max(Int((value * 100.0).rounded()), 100)
    }

    fileprivate func setSelectedLog(_ index: Int) {
        guard document.logs.indices.contains(index) else { return }
        selectedLogIndex = index
        setNextSceneRefreshTrigger(.structural)
        project = document.logs[index]
        selectedUnitID = project.units.first?.id
        if presentationState.selectedDetailPane == .synthetic, !canOpenSyntheticView {
            presentationState.selectedDetailPane = .preview
        }
    }

    fileprivate func commitCurrentProjectChanges() {
        commitCurrentProjectChanges(using: project)
    }

    fileprivate func commitCurrentProjectChanges(using updatedProject: Project) {
        guard document.logs.indices.contains(selectedLogIndex) else { return }
        document.logs[selectedLogIndex] = updatedProject
    }

    fileprivate func logsApplyingCurrentEdits() -> [Project] {
        var effectiveLogs = document.logs
        if effectiveLogs.indices.contains(selectedLogIndex) {
            effectiveLogs[selectedLogIndex] = project
        }
        return effectiveLogs
    }

    fileprivate func duplicatedLogTitle(for sourceTitle: String, existingTitles: [String]) -> String {
        let trimmed = sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Untitled Stratigraphic Log" : trimmed
        let preferred = "\(base) Copy"

        let existing = Set(existingTitles.map { $0.lowercased() })
        if !existing.contains(preferred.lowercased()) {
            return preferred
        }

        var suffix = 2
        while true {
            let candidate = "\(preferred) \(suffix)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            suffix += 1
        }
    }

    fileprivate func preferredExportBaseName(for title: String, index: Int) -> String {
        let slug = slugified(title)
        if slug.isEmpty {
            return "log-\(index + 1)"
        }
        return slug
    }

    fileprivate func slugified(_ value: String) -> String {
        let lowercase = value.lowercased()
        var scalars: [UnicodeScalar] = []
        var previousWasHyphen = false

        for scalar in lowercase.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
                previousWasHyphen = false
            } else if !previousWasHyphen {
                scalars.append("-")
                previousWasHyphen = true
            }
        }

        var slug = String(String.UnicodeScalarView(scalars))
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug
    }

    fileprivate func uniqueExportURL(
        in directoryURL: URL,
        basename: String,
        format: ExportFormat,
        reservedNames: inout Set<String>
    ) -> URL {
        let fileExtension = format.rawValue
        var suffix = 1

        while true {
            let name = suffix == 1 ? "\(basename).\(fileExtension)" : "\(basename)-\(suffix).\(fileExtension)"
            let key = name.lowercased()
            let candidate = directoryURL.appendingPathComponent(name)
            let alreadyExists = FileManager.default.fileExists(atPath: candidate.path)
            if !reservedNames.contains(key), !alreadyExists {
                reservedNames.insert(key)
                return candidate
            }
            suffix += 1
        }
    }

    fileprivate func scheduleAutoAdjust() {
        resizeDebounceTask?.cancel()
        let debounce = tuning.resizeDebounceNanoseconds
        resizeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled else { return }
            self?.applyAutoAdjustIfNeeded()
        }
    }

    fileprivate func applyAutoAdjustIfNeeded() {
        guard autoAdjustToWindow else { return }
        guard !isAutoAdjustSuspendedByManualZoom else { return }
        guard zoomMode != .manual else { return }
        applyFit(mode: zoomMode)
    }

    fileprivate func applyFit(mode: ZoomMode) {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        let targetZoom: Double
        switch mode {
        case .manual:
            return
        case .fitWindow:
            let widthZoom = fitScaleForWidth(applyingVisualBoost: false)
            let heightZoom = fitScaleForHeight()
            targetZoom = min(widthZoom, heightZoom)
        case .fitWidth:
            targetZoom = fitScaleForWidth(applyingVisualBoost: true)
        case .fitHeight:
            targetZoom = fitScaleForHeight()
        }

        #if DEBUG
        zoomLogger.debug(
            "applyFit mode=\(mode.rawValue, privacy: .public) viewport=(\(self.viewportSize.width, format: .fixed(precision: 2)), \(self.viewportSize.height, format: .fixed(precision: 2))) canvas=(\(self.scene.canvasSize.width, format: .fixed(precision: 2)), \(self.scene.canvasSize.height, format: .fixed(precision: 2))) target=\(targetZoom, format: .fixed(precision: 4)) clamped=\(self.zoomService.clampedAutoFitZoom(targetZoom, tuning: self.tuning), format: .fixed(precision: 4))"
        )
        #endif
        zoom = zoomService.clampedAutoFitZoom(targetZoom, tuning: tuning)
    }

    fileprivate func fitScaleForWidth(applyingVisualBoost: Bool) -> Double {
        zoomService.fitScaleForWidth(
            viewportWidth: viewportSize.width,
            canvasWidth: scene.canvasSize.width,
            applyingVisualBoost: applyingVisualBoost,
            tuning: tuning
        )
    }

    fileprivate func fitScaleForHeight() -> Double {
        zoomService.fitScaleForHeight(
            viewportHeight: viewportSize.height,
            canvasHeight: scene.canvasSize.height,
            tuning: tuning
        )
    }

    fileprivate var activeColorProfile: LithologyColorProfile? {
        guard let activeColorProfileID else { return nil }
        return colorProfiles.first(where: { $0.id == activeColorProfileID })
    }

    fileprivate func mutateActiveColorProfile(_ mutate: (inout LithologyColorProfile) -> Void) {
        guard let activeColorProfileID,
              let index = colorProfiles.firstIndex(where: { $0.id == activeColorProfileID }) else { return }

        mutate(&colorProfiles[index])
        colorProfiles[index].mappings = LithologyColorProfile.normalizedMappings(colorProfiles[index].mappings)
        persistColorPresetState()
    }

    fileprivate func loadColorPresetState() {
        let stored = colorPresetStore.load()
        colorProfiles = stored.profiles
        activeColorProfileID = stored.activeProfileID
    }

    fileprivate func persistColorPresetState() {
        colorPresetPersistTask?.cancel()
        let debounce = tuning.colorPresetPersistNanoseconds
        colorPresetPersistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: debounce)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.persistColorPresetStateNow()
            }
        }
    }

    fileprivate func persistColorPresetStateNow() {
        let normalized = colorProfileService.normalizedStore(
            profiles: colorProfiles,
            activeProfileID: activeColorProfileID
        )
        colorProfiles = normalized.profiles
        activeColorProfileID = normalized.activeProfileID
        colorPresetStore.save(normalized)
    }

    fileprivate static func initialPresentationState(from defaults: UserDefaults) -> EditorPresentationState {
        let inspectorOnLaunch = (defaults.object(forKey: EasyLogPreferencesKey.showsInspectorOnLaunch) as? Bool) ?? false
        let detailPaneRaw = defaults.string(forKey: EasyLogPreferencesKey.defaultDetailPane)
        let detailPane = EditorPresentationState.DetailPane(rawValue: detailPaneRaw ?? "") ?? .preview
        return EditorPresentationState(
            selectedDetailPane: detailPane,
            isInspectorPresented: inspectorOnLaunch
        )
    }
}
