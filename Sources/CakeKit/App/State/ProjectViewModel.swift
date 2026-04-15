import AppKit
import Combine
import CoreGraphics
import Foundation
import os

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

    @Published public private(set) var document: ProjectDocument
    @Published public var project: Project {
        didSet {
            commitCurrentProjectChanges(using: project)
            scheduleSceneRefresh(trigger: consumePendingSceneRefreshTrigger(default: .textInput))
        }
    }
    @Published public private(set) var selectedLogIndex: Int
    @Published public private(set) var scene: RenderScene
    @Published public private(set) var syntheticScene: SyntheticComparisonScene
    @Published public var selectedUnitID: UUID?
    @Published public private(set) var validationIssues: [ValidationIssue] = []
    @Published public var zoom: Double
    @Published public private(set) var zoomMode: ZoomMode
    @Published public private(set) var autoAdjustToWindow: Bool
    @Published public private(set) var presentationState = EditorPresentationState()
    @Published public private(set) var statusMessage: String = "Ready"
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var colorProfiles: [LithologyColorProfile] = []
    @Published public private(set) var activeColorProfileID: UUID?
    @Published public private(set) var editorState: EditorState
    @Published public private(set) var previewState: PreviewState

    public private(set) var projectURL: URL?
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
        let effectiveLogs = logsApplyingCurrentEdits()
        return effectiveLogs.count >= 2 && effectiveLogs.allSatisfy { $0.settings.zeroLevelAltitudeMeters != nil }
    }
    public var canRemoveCurrentLog: Bool {
        document.logs.count > 1
    }
    public var canResetManualZoom: Bool {
        hasManualZoomOverride
    }

    private let renderer: LogRenderer
    private let openProjectUseCase: OpenProjectUseCase
    private let saveProjectUseCase: SaveProjectUseCase
    private let exportProjectUseCase: ExportProjectUseCase
    private let fileDialogService: FileDialoging
    private let addUnitUseCase = AddUnitUseCase()
    private let deleteSelectedUnitUseCase = DeleteSelectedUnitUseCase()
    private let moveSelectedUnitUseCase = MoveSelectedUnitUseCase()
    private let colorPresetStore: any LithologyColorPresetPersisting
    private let sceneComputationService: SceneComputationService
    private let rasterCache = SceneRasterCache(maxBytes: 160 * 1024 * 1024)
    private var cancellables = Set<AnyCancellable>()
    private var viewportSize: CGSize = .zero
    private var isAutoAdjustSuspendedByManualZoom = false
    private var hasManualZoomOverride = false
    private var didApplyInitialWidthFit = false
    private var sceneRefreshTask: Task<Void, Never>?
    private var sceneRefreshGeneration: UInt64 = 0
    private var pendingSceneRefreshTrigger: SceneRefreshTrigger = .textInput
    private var resizeDebounceTask: Task<Void, Never>?
    private var previewRasterTask: Task<Void, Never>?
    private var syntheticRasterTask: Task<Void, Never>?
    private var colorPresetPersistTask: Task<Void, Never>?
    private var isManualZoomInteractionActive = false
    private let zoomLogger = Logger(subsystem: "Cake", category: "Zoom")
    private let perfSignposter = OSSignposter(subsystem: "Cake", category: "Perf")

    private static let minZoom = 0.5
    private static let maxZoom = 2.5
    private static let defaultZoom = 1.0
    private static let fitWidthVisualBoost = 1.12
    private static let maxRenderScale = 6.0
    private static let resizeDebounceNanoseconds: UInt64 = 120_000_000
    private static let colorPresetPersistNanoseconds: UInt64 = 300_000_000

    public init(
        project: Project = .sample,
        renderer: LogRenderer = CakeRenderer(),
        store: ProjectStore = JSONProjectStore(),
        exporter: Exporter = CompositeExporter(),
        fileDialogService: FileDialoging = AppKitFileDialogService(),
        defaults: UserDefaults = .standard,
        colorPresetStore: (any LithologyColorPresetPersisting)? = nil
    ) {
        let initialDocument = ProjectDocument(logs: [project])
        let initialSelectedUnitID = project.units.first?.id
        let initialScene = renderer.makeScene(project: project)
        self.project = project
        self.document = initialDocument
        self.selectedLogIndex = 0
        self.renderer = renderer
        self.openProjectUseCase = OpenProjectUseCase(store: store)
        self.saveProjectUseCase = SaveProjectUseCase(store: store)
        self.exportProjectUseCase = ExportProjectUseCase(exporter: exporter)
        self.fileDialogService = fileDialogService
        self.colorPresetStore = colorPresetStore ?? UserDefaultsLithologyColorPresetStore(defaults: defaults)
        // Launch defaults are always width-fitted to avoid opening in a stale manual zoom
        // state when the zoom-mode selector is hidden from the UI.
        self.zoom = Self.defaultZoom
        self.zoomMode = .fitWidth
        self.autoAdjustToWindow = true
        self.scene = initialScene
        self.syntheticScene = .empty
        self.selectedUnitID = initialSelectedUnitID
        self.sceneComputationService = SceneComputationService(renderer: renderer)
        self.editorState = EditorState(
            document: initialDocument,
            project: project,
            selectedLogIndex: 0,
            selectedUnitID: initialSelectedUnitID,
            presentationState: EditorPresentationState(),
            statusMessage: "Ready",
            errorMessage: nil
        )
        self.previewState = PreviewState(
            scene: initialScene,
            syntheticScene: .empty,
            validationIssues: [],
            zoom: Self.defaultZoom,
            zoomMode: .fitWidth,
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
        setNextSceneRefreshTrigger(.structural)
        scheduleSceneRefresh(trigger: .structural)
    }

    public func makeSyntheticComparisonScene() -> SyntheticComparisonScene {
        syntheticScene
    }

    public func selectLog(at index: Int) {
        setNextSceneRefreshTrigger(.structural)
        commitCurrentProjectChanges()
        setSelectedLog(index)
        statusMessage = "Selected log \(index + 1)"
    }

    public func addLog() {
        setNextSceneRefreshTrigger(.structural)
        commitCurrentProjectChanges()
        document.logs.append(Project())
        setSelectedLog(document.logs.count - 1)
        presentationState.selectedDetailPane = .preview
        statusMessage = "Added new log"
    }

    public func duplicateCurrentLog() {
        guard document.logs.indices.contains(selectedLogIndex) else { return }
        setNextSceneRefreshTrigger(.structural)
        commitCurrentProjectChanges()

        var duplicated = document.logs[selectedLogIndex]
        let existingTitles = document.logs.map { $0.metadata.title }
        duplicated.metadata.title = duplicatedLogTitle(for: duplicated.metadata.title, existingTitles: existingTitles)

        let insertIndex = selectedLogIndex + 1
        document.logs.insert(duplicated, at: insertIndex)
        setSelectedLog(insertIndex)
        presentationState.selectedDetailPane = .preview
        statusMessage = "Duplicated current log"
    }

    public func removeLog(at index: Int) {
        guard document.logs.indices.contains(index) else { return }
        guard document.logs.count > 1 else { return }
        setNextSceneRefreshTrigger(.structural)
        commitCurrentProjectChanges()

        document.logs.remove(at: index)

        let nextIndex: Int
        if selectedLogIndex > index {
            nextIndex = selectedLogIndex - 1
        } else if selectedLogIndex == index {
            nextIndex = min(index, document.logs.count - 1)
        } else {
            nextIndex = selectedLogIndex
        }

        setSelectedLog(nextIndex)
        if !canOpenSyntheticView {
            presentationState.selectedDetailPane = .preview
        }
        statusMessage = "Removed log \(index + 1)"
    }

    public func removeCurrentLog() {
        removeLog(at: selectedLogIndex)
    }

    public func addUnit() {
        setNextSceneRefreshTrigger(.structural)
        selectedUnitID = addUnitUseCase.execute(project: &project)
    }

    public func removeSelectedUnit() {
        setNextSceneRefreshTrigger(.structural)
        selectedUnitID = deleteSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID)
    }

    public func moveUnits(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }
        setNextSceneRefreshTrigger(.structural)

        let movedUnits = source.map { project.units[$0] }
        for index in source.sorted(by: >) {
            project.units.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        project.units.insert(contentsOf: movedUnits, at: adjustedDestination)
        statusMessage = "Reordered units"
    }

    public func moveSelectedUnitUp() {
        setNextSceneRefreshTrigger(.structural)
        let before = selectedUnitID
        moveSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID, direction: .up)
        guard let current = selectedUnitID else { return }
        if before == current, project.units.first?.id != current {
            statusMessage = "Moved selected unit up"
        }
    }

    public func moveSelectedUnitDown() {
        setNextSceneRefreshTrigger(.structural)
        let before = selectedUnitID
        moveSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID, direction: .down)
        guard let current = selectedUnitID else { return }
        if before == current, project.units.last?.id != current {
            statusMessage = "Moved selected unit down"
        }
    }

    public func zoomIn() {
        setManualZoom(zoom + 0.1)
        statusMessage = "Zoom \(Int((zoom * 100).rounded()))%"
    }

    public func zoomOut() {
        setManualZoom(zoom - 0.1)
        statusMessage = "Zoom \(Int((zoom * 100).rounded()))%"
    }

    public func fitToWindow() {
        setZoomMode(.fitWindow)
        statusMessage = "Zoom fit window"
    }

    public func resetZoom() {
        hasManualZoomOverride = false
        setZoomMode(.fitWindow)
        statusMessage = "Zoom fit window"
    }

    public func setManualZoom(_ value: Double, isInteracting: Bool = false) {
        let clamped = Self.clampedZoom(value)
        let didChange = abs(clamped - zoom) > 0.0001
        zoom = clamped

        guard didChange else { return }
        isManualZoomInteractionActive = isInteracting
        hasManualZoomOverride = true

        if autoAdjustToWindow, zoomMode != .manual {
            isAutoAdjustSuspendedByManualZoom = true
            if !isInteracting {
                scheduleRasterizationForCurrentZoom()
            }
            return
        }

        zoomMode = .manual
        if !isInteracting {
            scheduleRasterizationForCurrentZoom()
        }
    }

    public func finalizeManualZoomInteraction() {
        guard isManualZoomInteractionActive else { return }
        isManualZoomInteractionActive = false
        scheduleRasterizationForCurrentZoom()
    }

    public func setZoomMode(_ mode: ZoomMode) {
        zoomMode = mode

        guard mode != .manual else { return }
        hasManualZoomOverride = false
        isAutoAdjustSuspendedByManualZoom = false
        applyFit(mode: mode)
    }

    public func updateProjectSettings(_ newSettings: ProjectSettings, trigger: SceneRefreshTrigger = .slider) {
        setNextSceneRefreshTrigger(trigger)
        var updatedProject = project
        updatedProject.settings = newSettings
        project = updatedProject
    }

    public func selectDetailPane(_ pane: EditorPresentationState.DetailPane) {
        let targetPane: EditorPresentationState.DetailPane =
            (pane == .synthetic && !canOpenSyntheticView) ? .preview : pane
        guard presentationState.selectedDetailPane != targetPane else { return }
        presentationState.selectedDetailPane = targetPane
    }

    public func toggleInspector() {
        presentationState.isInspectorPresented.toggle()
    }

    public func setInspectorPresented(_ isPresented: Bool) {
        presentationState.isInspectorPresented = isPresented
    }

    public func setAutoAdjustToWindow(_ enabled: Bool) {
        autoAdjustToWindow = enabled

        if enabled {
            hasManualZoomOverride = false
            isAutoAdjustSuspendedByManualZoom = false
            applyAutoAdjustIfNeeded()
        }
    }

    public func updateViewportSize(_ size: CGSize) {
        let normalized = CGSize(width: max(0, size.width), height: max(0, size.height))
        guard normalized != viewportSize else { return }
        let hadViewport = viewportSize.width > 0 && viewportSize.height > 0
        #if DEBUG
        zoomLogger.debug(
            "updateViewportSize raw=(\(size.width, format: .fixed(precision: 2)), \(size.height, format: .fixed(precision: 2))) normalized=(\(normalized.width, format: .fixed(precision: 2)), \(normalized.height, format: .fixed(precision: 2))) oldViewport=(\(self.viewportSize.width, format: .fixed(precision: 2)), \(self.viewportSize.height, format: .fixed(precision: 2))) mode=\(self.zoomMode.rawValue, privacy: .public) zoom=\(self.zoom, format: .fixed(precision: 4)) autoAdjust=\(self.autoAdjustToWindow) manualOverride=\(self.hasManualZoomOverride)"
        )
        #endif
        viewportSize = normalized

        // Force a one-time fit-to-width as soon as the first real viewport is known.
        if !didApplyInitialWidthFit, viewportSize.width > 0 {
            didApplyInitialWidthFit = true
            hasManualZoomOverride = false
            isAutoAdjustSuspendedByManualZoom = false
            zoomMode = .fitWidth
            applyFit(mode: .fitWidth)
            #if DEBUG
            zoomLogger.debug(
                "initial fit-width forced -> zoom=\(self.zoom, format: .fixed(precision: 4)) viewportWidth=\(self.viewportSize.width, format: .fixed(precision: 2)) canvasWidth=\(self.scene.canvasSize.width, format: .fixed(precision: 2))"
            )
            #endif
            return
        }

        // Apply fit immediately on first measurable viewport so initial launch
        // starts at the expected width-fitted zoom instead of waiting for debounce.
        if !hadViewport {
            applyAutoAdjustIfNeeded()
            return
        }

        scheduleAutoAdjust()
    }

    public func newProject() {
        flushPendingColorPresetPersistence()
        setNextSceneRefreshTrigger(.structural)
        let newDocument = ProjectDocument(logs: [Project()])
        document = newDocument
        setSelectedLog(0)
        projectURL = nil
        presentationState = EditorPresentationState()
        isAutoAdjustSuspendedByManualZoom = false
        hasManualZoomOverride = false
        statusMessage = "New project"
        errorMessage = nil
    }

    public func openProjectViaPanel() {
        guard let url = fileDialogService.chooseProjectToOpen() else { return }
        openProject(at: url)
    }

    public func saveProjectViaPanelIfNeeded() {
        if let existingURL = projectURL {
            saveProject(at: existingURL)
            return
        }
        guard let url = fileDialogService.chooseProjectToSave() else { return }
        saveProject(at: url)
    }

    public func exportViaPanel(format: ExportFormat, dpi: Double = 300) {
        guard let url = fileDialogService.chooseExportDestination(format: format) else { return }
        exportProject(to: url, format: format, dpi: dpi)
    }

    public func exportAllViaPanel(format: ExportFormat, dpi: Double = 300) {
        guard let directoryURL = fileDialogService.chooseExportDirectory() else { return }
        exportAllProjects(to: directoryURL, format: format, dpi: dpi)
    }

    public func clearError() {
        errorMessage = nil
    }

    public func flushPendingColorPresetPersistence() {
        colorPresetPersistTask?.cancel()
        persistColorPresetStateNow()
    }

    public func createColorProfile(name: String) {
        let resolved = uniqueColorProfileName(base: LithologyColorProfile.normalizedName(name))
        let profile = LithologyColorProfile(name: resolved)
        colorProfiles.append(profile)
        activeColorProfileID = profile.id
        persistColorPresetState()
    }

    public func renameColorProfile(id: UUID, name: String) {
        guard let index = colorProfiles.firstIndex(where: { $0.id == id }) else { return }
        let resolved = uniqueColorProfileName(
            base: LithologyColorProfile.normalizedName(name, fallback: colorProfiles[index].name),
            excludingID: id
        )
        colorProfiles[index].name = resolved
        persistColorPresetState()
    }

    public func deleteColorProfile(id: UUID) {
        guard colorProfiles.count > 1 else { return }
        guard let index = colorProfiles.firstIndex(where: { $0.id == id }) else { return }

        colorProfiles.remove(at: index)
        if activeColorProfileID == id {
            activeColorProfileID = colorProfiles.first?.id
        }
        persistColorPresetState()
    }

    public func setActiveColorProfile(id: UUID) {
        guard colorProfiles.contains(where: { $0.id == id }) else { return }
        activeColorProfileID = id
        persistColorPresetState()
    }

    public func setLithologyColorPreset(usgsCode: Int, hex: String) {
        guard let normalized = LithologyColorProfile.normalizedHex(hex) else { return }
        mutateActiveColorProfile { profile in
            profile.mappings[usgsCode] = normalized
        }
    }

    public func removeLithologyColorPreset(usgsCode: Int) {
        mutateActiveColorProfile { profile in
            profile.mappings.removeValue(forKey: usgsCode)
        }
    }

    public func presetColor(for usgsCode: Int) -> String? {
        activeColorProfile?.mappings[usgsCode]
    }

    public func applyPresetToSelectedUnit() {
        guard let selectedUnitIndex else { return }
        let usgsCode = project.units[selectedUnitIndex].usgsLithologyCode
        guard let presetHex = presetColor(for: usgsCode) else { return }
        setNextSceneRefreshTrigger(.structural)
        project.units[selectedUnitIndex].lithologyColorHex = presetHex
        statusMessage = "Applied profile color to selected unit"
    }

    public func openProject(at url: URL) {
        do {
            flushPendingColorPresetPersistence()
            setNextSceneRefreshTrigger(.structural)
            let loaded = try openProjectUseCase.execute(url: url)
            document = ProjectDocument(logs: loaded.logs)
            projectURL = url
            setSelectedLog(0)
            presentationState.selectedDetailPane = .preview
            isAutoAdjustSuspendedByManualZoom = false
            hasManualZoomOverride = false
            statusMessage = "Opened \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not open project: \(error.localizedDescription). Check that the JSON file is valid and try again."
        }
    }

    public func saveProject(at url: URL) {
        do {
            flushPendingColorPresetPersistence()
            commitCurrentProjectChanges()
            let saved = try saveProjectUseCase.execute(document: document, url: url)
            document = saved
            setSelectedLog(min(selectedLogIndex, max(saved.logs.count - 1, 0)))
            projectURL = url
            statusMessage = "Saved \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not save project: \(error.localizedDescription). Verify write permissions and try again."
        }
    }

    public func exportProject(to url: URL, format: ExportFormat, dpi: Double = 300) {
        do {
            try exportProjectUseCase.execute(scene: scene, url: url, format: format, dpi: dpi)
            statusMessage = "Exported \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not export file: \(error.localizedDescription). Choose a writable location and retry."
        }
    }

    public func exportAllProjects(to directoryURL: URL, format: ExportFormat, dpi: Double = 300) {
        commitCurrentProjectChanges()

        var successCount = 0
        var failureDetails: [String] = []
        var reservedFilenames = Set<String>()

        for (index, log) in document.logs.enumerated() {
            let scene = renderer.makeScene(project: log)
            let basename = preferredExportBaseName(for: log.metadata.title, index: index)
            let destinationURL = uniqueExportURL(
                in: directoryURL,
                basename: basename,
                format: format,
                reservedNames: &reservedFilenames
            )

            do {
                try exportProjectUseCase.execute(scene: scene, url: destinationURL, format: format, dpi: dpi)
                successCount += 1
            } catch {
                failureDetails.append("\(destinationURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        let total = document.logs.count
        if successCount == 0 {
            errorMessage = "Could not export any logs. \(failureDetails.first ?? "Choose a writable location and retry.")"
            return
        }

        if failureDetails.isEmpty {
            statusMessage = "Exported \(successCount) logs to \(directoryURL.lastPathComponent)"
        } else {
            statusMessage = "Exported \(successCount)/\(total) logs to \(directoryURL.lastPathComponent)"
        }
        errorMessage = nil
    }

    deinit {
        sceneRefreshTask?.cancel()
        resizeDebounceTask?.cancel()
        previewRasterTask?.cancel()
        syntheticRasterTask?.cancel()
        colorPresetPersistTask?.cancel()
    }

    private func configureStateMirrors() {
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

    private func setNextSceneRefreshTrigger(_ trigger: SceneRefreshTrigger) {
        switch (pendingSceneRefreshTrigger, trigger) {
        case (.structural, _):
            return
        case (_, .structural):
            pendingSceneRefreshTrigger = .structural
        case (.slider, .textInput):
            return
        default:
            pendingSceneRefreshTrigger = trigger
        }
    }

    private func consumePendingSceneRefreshTrigger(default fallback: SceneRefreshTrigger) -> SceneRefreshTrigger {
        let trigger = pendingSceneRefreshTrigger
        pendingSceneRefreshTrigger = fallback
        return trigger
    }

    private func scheduleSceneRefresh(trigger: SceneRefreshTrigger) {
        sceneRefreshTask?.cancel()
        sceneRefreshGeneration &+= 1
        let generation = sceneRefreshGeneration
        let snapshotProject = project
        let snapshotLogs = logsApplyingCurrentEdits()
        let snapshotSelectedLogIndex = selectedLogIndex
        let shouldComputeSynthetic = snapshotLogs.count >= 2 && snapshotLogs.allSatisfy { $0.settings.zeroLevelAltitudeMeters != nil }
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

    private func schedulePreviewRasterization(for scene: RenderScene) {
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

    private func scheduleSyntheticRasterization(for scene: SyntheticComparisonScene) {
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

    private func rasterImage(
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

    private static func renderRasterImage(
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

    private func scheduleRasterizationForCurrentZoom() {
        schedulePreviewRasterization(for: scene)
        if canOpenSyntheticView {
            scheduleSyntheticRasterization(for: syntheticScene)
        }
    }

    private func resolvedRenderScale() -> Double {
        let backingScale = max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
        let zoomFactor = max(zoom, 1.0)
        return min(backingScale * zoomFactor, Self.maxRenderScale)
    }

    private func quantizedRenderScaleHundredths(_ value: Double) -> Int {
        max(Int((value * 100.0).rounded()), 100)
    }

    private func setSelectedLog(_ index: Int) {
        guard document.logs.indices.contains(index) else { return }
        selectedLogIndex = index
        setNextSceneRefreshTrigger(.structural)
        project = document.logs[index]
        selectedUnitID = project.units.first?.id
        if presentationState.selectedDetailPane == .synthetic, !canOpenSyntheticView {
            presentationState.selectedDetailPane = .preview
        }
    }

    private func commitCurrentProjectChanges() {
        commitCurrentProjectChanges(using: project)
    }

    private func commitCurrentProjectChanges(using updatedProject: Project) {
        guard document.logs.indices.contains(selectedLogIndex) else { return }
        document.logs[selectedLogIndex] = updatedProject
    }

    private func logsApplyingCurrentEdits() -> [Project] {
        var effectiveLogs = document.logs
        if effectiveLogs.indices.contains(selectedLogIndex) {
            effectiveLogs[selectedLogIndex] = project
        }
        return effectiveLogs
    }

    private func duplicatedLogTitle(for sourceTitle: String, existingTitles: [String]) -> String {
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

    private func preferredExportBaseName(for title: String, index: Int) -> String {
        let slug = slugified(title)
        if slug.isEmpty {
            return "log-\(index + 1)"
        }
        return slug
    }

    private func slugified(_ value: String) -> String {
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

    private func uniqueExportURL(
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

    private func scheduleAutoAdjust() {
        resizeDebounceTask?.cancel()
        resizeDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.resizeDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.applyAutoAdjustIfNeeded()
        }
    }

    private func applyAutoAdjustIfNeeded() {
        guard autoAdjustToWindow else { return }
        guard !isAutoAdjustSuspendedByManualZoom else { return }
        guard zoomMode != .manual else { return }
        applyFit(mode: zoomMode)
    }

    private func applyFit(mode: ZoomMode) {
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
            "applyFit mode=\(mode.rawValue, privacy: .public) viewport=(\(self.viewportSize.width, format: .fixed(precision: 2)), \(self.viewportSize.height, format: .fixed(precision: 2))) canvas=(\(self.scene.canvasSize.width, format: .fixed(precision: 2)), \(self.scene.canvasSize.height, format: .fixed(precision: 2))) target=\(targetZoom, format: .fixed(precision: 4)) clamped=\(Self.clampedAutoFitZoom(targetZoom), format: .fixed(precision: 4))"
        )
        #endif
        zoom = Self.clampedAutoFitZoom(targetZoom)
    }

    private func fitScaleForWidth(applyingVisualBoost: Bool) -> Double {
        guard scene.canvasSize.width > 0 else { return Self.defaultZoom }
        let base = viewportSize.width / scene.canvasSize.width
        guard applyingVisualBoost, base > 1 else { return base }
        return base * Self.fitWidthVisualBoost
    }

    private func fitScaleForHeight() -> Double {
        guard scene.canvasSize.height > 0 else { return Self.defaultZoom }
        return viewportSize.height / scene.canvasSize.height
    }

    private static func clampedZoom(_ value: Double) -> Double {
        min(max(value, minZoom), maxZoom)
    }

    private static func clampedAutoFitZoom(_ value: Double) -> Double {
        max(value, minZoom)
    }

    private var activeColorProfile: LithologyColorProfile? {
        guard let activeColorProfileID else { return nil }
        return colorProfiles.first(where: { $0.id == activeColorProfileID })
    }

    private func mutateActiveColorProfile(_ mutate: (inout LithologyColorProfile) -> Void) {
        guard let activeColorProfileID,
              let index = colorProfiles.firstIndex(where: { $0.id == activeColorProfileID }) else { return }

        mutate(&colorProfiles[index])
        colorProfiles[index].mappings = LithologyColorProfile.normalizedMappings(colorProfiles[index].mappings)
        persistColorPresetState()
    }

    private func uniqueColorProfileName(base: String, excludingID: UUID? = nil) -> String {
        let baseName = LithologyColorProfile.normalizedName(base)
        let existing = Set(
            colorProfiles
                .filter { $0.id != excludingID }
                .map { $0.name.lowercased() }
        )

        if !existing.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 2
        while true {
            let candidate = "\(baseName) \(suffix)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            suffix += 1
        }
    }

    private func loadColorPresetState() {
        let stored = colorPresetStore.load()
        colorProfiles = stored.profiles
        activeColorProfileID = stored.activeProfileID
    }

    private func persistColorPresetState() {
        colorPresetPersistTask?.cancel()
        colorPresetPersistTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.colorPresetPersistNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.persistColorPresetStateNow()
            }
        }
    }

    private func persistColorPresetStateNow() {
        let normalized = LithologyColorPresetStore(
            profiles: colorProfiles,
            activeProfileID: activeColorProfileID
        )
        colorProfiles = normalized.profiles
        activeColorProfileID = normalized.activeProfileID
        colorPresetStore.save(normalized)
    }
}
