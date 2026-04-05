import Combine
import CoreGraphics
import Foundation

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
    @Published public var project: Project
    @Published public private(set) var selectedLogIndex: Int
    @Published public private(set) var scene: RenderScene
    @Published public var selectedUnitID: UUID?
    @Published public private(set) var validationIssues: [ValidationIssue] = []
    @Published public var zoom: Double
    @Published public private(set) var zoomMode: ZoomMode
    @Published public private(set) var autoAdjustToWindow: Bool
    @Published public private(set) var statusMessage: String = "Ready"
    @Published public private(set) var errorMessage: String?

    public private(set) var projectURL: URL?

    public var logs: [Project] { document.logs }
    public var canOpenSyntheticView: Bool {
        let effectiveLogs = logsApplyingCurrentEdits()
        return effectiveLogs.count >= 2 && effectiveLogs.allSatisfy { $0.settings.zeroLevelAltitudeMeters != nil }
    }

    private let renderer: LogRenderer
    private let openProjectUseCase: OpenProjectUseCase
    private let saveProjectUseCase: SaveProjectUseCase
    private let exportProjectUseCase: ExportProjectUseCase
    private let fileDialogService: FileDialoging
    private let addUnitUseCase = AddUnitUseCase()
    private let deleteSelectedUnitUseCase = DeleteSelectedUnitUseCase()
    private let moveSelectedUnitUseCase = MoveSelectedUnitUseCase()
    private var cancellables = Set<AnyCancellable>()
    private let defaults: UserDefaults
    private var viewportSize: CGSize = .zero
    private var isAutoAdjustSuspendedByManualZoom = false
    private var resizeDebounceTask: Task<Void, Never>?

    private static let minZoom = 0.5
    private static let maxZoom = 2.5
    private static let defaultZoom = 1.0
    private static let resizeDebounceNanoseconds: UInt64 = 120_000_000
    private static let zoomDefaultsKey = "cake.viewer.zoom"
    private static let zoomModeDefaultsKey = "cake.viewer.zoomMode"
    private static let autoAdjustDefaultsKey = "cake.viewer.autoAdjust"

    public init(
        project: Project = .sample,
        renderer: LogRenderer = CakeRenderer(),
        store: ProjectStore = JSONProjectStore(),
        exporter: Exporter = CompositeExporter(),
        fileDialogService: FileDialoging = AppKitFileDialogService(),
        defaults: UserDefaults = .standard
    ) {
        self.project = project
        self.document = ProjectDocument(logs: [project])
        self.selectedLogIndex = 0
        self.renderer = renderer
        self.openProjectUseCase = OpenProjectUseCase(store: store)
        self.saveProjectUseCase = SaveProjectUseCase(store: store)
        self.exportProjectUseCase = ExportProjectUseCase(exporter: exporter)
        self.fileDialogService = fileDialogService
        self.defaults = defaults
        let savedZoom = defaults.object(forKey: Self.zoomDefaultsKey) as? Double
        self.zoom = Self.clampedZoom(savedZoom ?? Self.defaultZoom)
        if let rawMode = defaults.string(forKey: Self.zoomModeDefaultsKey), let parsedMode = ZoomMode(rawValue: rawMode) {
            self.zoomMode = parsedMode
        } else {
            self.zoomMode = .manual
        }
        self.autoAdjustToWindow = defaults.bool(forKey: Self.autoAdjustDefaultsKey)
        self.scene = renderer.makeScene(project: project)
        self.selectedUnitID = project.units.first?.id

        $project
            .debounce(for: .milliseconds(33), scheduler: RunLoop.main)
            .sink { [weak self] updatedProject in
                guard let self else { return }
                self.commitCurrentProjectChanges(using: updatedProject)
                self.refreshScene()
            }
            .store(in: &cancellables)

        refreshScene()
    }

    public var selectedUnitIndex: Int? {
        guard let selectedUnitID else { return nil }
        return project.units.firstIndex(where: { $0.id == selectedUnitID })
    }

    public func refreshScene() {
        validationIssues = ProjectValidator.validate(project)
        scene = renderer.makeScene(project: project)
        applyAutoAdjustIfNeeded()
        statusMessage = validationIssues.isEmpty ? "Scene updated" : "Scene updated with validation warnings"
    }

    public func makeSyntheticComparisonScene() -> SyntheticComparisonScene {
        let effectiveLogs = logsApplyingCurrentEdits()
        guard effectiveLogs.count >= 2 else { return .empty }
        guard effectiveLogs.allSatisfy({ $0.settings.zeroLevelAltitudeMeters != nil }) else { return .empty }
        guard canOpenSyntheticView else { return .empty }
        return SyntheticComparisonSceneBuilder.make(
            logs: effectiveLogs,
            selectedLogIndex: selectedLogIndex,
            renderer: renderer
        )
    }

    public func selectLog(at index: Int) {
        commitCurrentProjectChanges()
        setSelectedLog(index)
        statusMessage = "Selected log \(index + 1)"
    }

    public func addLog() {
        commitCurrentProjectChanges()
        document.logs.append(Project())
        setSelectedLog(document.logs.count - 1)
        statusMessage = "Added new log"
    }

    public func duplicateCurrentLog() {
        guard document.logs.indices.contains(selectedLogIndex) else { return }
        commitCurrentProjectChanges()

        var duplicated = document.logs[selectedLogIndex]
        let existingTitles = document.logs.map { $0.metadata.title }
        duplicated.metadata.title = duplicatedLogTitle(for: duplicated.metadata.title, existingTitles: existingTitles)

        let insertIndex = selectedLogIndex + 1
        document.logs.insert(duplicated, at: insertIndex)
        setSelectedLog(insertIndex)
        statusMessage = "Duplicated current log"
    }

    public func removeLog(at index: Int) {
        guard document.logs.indices.contains(index) else { return }
        guard document.logs.count > 1 else { return }
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
        statusMessage = "Removed log \(index + 1)"
    }

    public func addUnit() {
        selectedUnitID = addUnitUseCase.execute(project: &project)
    }

    public func removeSelectedUnit() {
        selectedUnitID = deleteSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID)
    }

    public func moveUnits(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty else { return }

        let movedUnits = source.map { project.units[$0] }
        for index in source.sorted(by: >) {
            project.units.remove(at: index)
        }
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        project.units.insert(contentsOf: movedUnits, at: adjustedDestination)
        statusMessage = "Reordered units"
    }

    public func moveSelectedUnitUp() {
        let before = selectedUnitID
        moveSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID, direction: .up)
        guard let current = selectedUnitID else { return }
        if before == current, project.units.first?.id != current {
            statusMessage = "Moved selected unit up"
        }
    }

    public func moveSelectedUnitDown() {
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

    public func resetZoom() {
        setManualZoom(1.0)
        statusMessage = "Zoom 100%"
    }

    public func setManualZoom(_ value: Double) {
        zoom = Self.clampedZoom(value)
        persistZoom()

        if autoAdjustToWindow, zoomMode != .manual {
            isAutoAdjustSuspendedByManualZoom = true
            return
        }

        zoomMode = .manual
        persistZoomMode()
    }

    public func setZoomMode(_ mode: ZoomMode) {
        zoomMode = mode
        persistZoomMode()

        guard mode != .manual else { return }
        isAutoAdjustSuspendedByManualZoom = false
        applyFit(mode: mode)
    }

    public func setAutoAdjustToWindow(_ enabled: Bool) {
        autoAdjustToWindow = enabled
        defaults.set(enabled, forKey: Self.autoAdjustDefaultsKey)

        if enabled {
            isAutoAdjustSuspendedByManualZoom = false
            applyAutoAdjustIfNeeded()
        }
    }

    public func updateViewportSize(_ size: CGSize) {
        let normalized = CGSize(width: max(0, size.width), height: max(0, size.height))
        guard normalized != viewportSize else { return }
        viewportSize = normalized
        scheduleAutoAdjust()
    }

    public func newProject() {
        let newDocument = ProjectDocument(logs: [Project()])
        document = newDocument
        setSelectedLog(0)
        projectURL = nil
        isAutoAdjustSuspendedByManualZoom = false
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

    public func openProject(at url: URL) {
        do {
            let loaded = try openProjectUseCase.execute(url: url)
            document = ProjectDocument(logs: loaded.logs)
            projectURL = url
            setSelectedLog(0)
            isAutoAdjustSuspendedByManualZoom = false
            applyAutoAdjustIfNeeded()
            statusMessage = "Opened \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not open project: \(error.localizedDescription). Check that the JSON file is valid and try again."
        }
    }

    public func saveProject(at url: URL) {
        do {
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

    private func setSelectedLog(_ index: Int) {
        guard document.logs.indices.contains(index) else { return }
        selectedLogIndex = index
        project = document.logs[index]
        selectedUnitID = project.units.first?.id
        refreshScene()
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
            let widthZoom = fitScaleForWidth()
            let heightZoom = fitScaleForHeight()
            targetZoom = min(widthZoom, heightZoom)
        case .fitWidth:
            targetZoom = fitScaleForWidth()
        case .fitHeight:
            targetZoom = fitScaleForHeight()
        }

        zoom = Self.clampedZoom(targetZoom)
        persistZoom()
    }

    private func fitScaleForWidth() -> Double {
        guard scene.canvasSize.width > 0 else { return Self.defaultZoom }
        return viewportSize.width / scene.canvasSize.width
    }

    private func fitScaleForHeight() -> Double {
        guard scene.canvasSize.height > 0 else { return Self.defaultZoom }
        return viewportSize.height / scene.canvasSize.height
    }

    private func persistZoom() {
        defaults.set(zoom, forKey: Self.zoomDefaultsKey)
    }

    private func persistZoomMode() {
        defaults.set(zoomMode.rawValue, forKey: Self.zoomModeDefaultsKey)
    }

    private static func clampedZoom(_ value: Double) -> Double {
        min(max(value, minZoom), maxZoom)
    }
}
