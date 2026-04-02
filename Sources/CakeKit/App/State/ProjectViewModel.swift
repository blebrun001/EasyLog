import Combine
import Foundation

@MainActor
/// UI-facing state holder orchestrating project editing, rendering, I/O and export.
public final class ProjectViewModel: ObservableObject {
    @Published public var project: Project
    @Published public private(set) var scene: RenderScene
    @Published public var selectedUnitID: UUID?
    @Published public private(set) var validationIssues: [ValidationIssue] = []
    @Published public var zoom: Double = 1.0
    @Published public private(set) var statusMessage: String = "Ready"
    @Published public private(set) var errorMessage: String?

    public private(set) var projectURL: URL?

    private let renderer: LogRenderer
    private let openProjectUseCase: OpenProjectUseCase
    private let saveProjectUseCase: SaveProjectUseCase
    private let exportProjectUseCase: ExportProjectUseCase
    private let fileDialogService: FileDialoging
    private let addUnitUseCase = AddUnitUseCase()
    private let deleteSelectedUnitUseCase = DeleteSelectedUnitUseCase()
    private let moveSelectedUnitUseCase = MoveSelectedUnitUseCase()
    private var cancellables = Set<AnyCancellable>()

    public init(
        project: Project = .sample,
        renderer: LogRenderer = CakeRenderer(),
        store: ProjectStore = JSONProjectStore(),
        exporter: Exporter = CompositeExporter(),
        fileDialogService: FileDialoging = AppKitFileDialogService()
    ) {
        self.project = project
        self.renderer = renderer
        self.openProjectUseCase = OpenProjectUseCase(store: store)
        self.saveProjectUseCase = SaveProjectUseCase(store: store)
        self.exportProjectUseCase = ExportProjectUseCase(exporter: exporter)
        self.fileDialogService = fileDialogService
        self.scene = renderer.makeScene(project: project)
        self.selectedUnitID = project.units.first?.id

        $project
            .debounce(for: .milliseconds(33), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshScene()
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
        statusMessage = validationIssues.isEmpty ? "Scene updated" : "Scene updated with validation warnings"
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
        zoom = min(2.5, zoom + 0.1)
        statusMessage = "Zoom \(Int((zoom * 100).rounded()))%"
    }

    public func zoomOut() {
        zoom = max(0.5, zoom - 0.1)
        statusMessage = "Zoom \(Int((zoom * 100).rounded()))%"
    }

    public func resetZoom() {
        zoom = 1.0
        statusMessage = "Zoom 100%"
    }

    public func newProject() {
        project = Project()
        selectedUnitID = nil
        projectURL = nil
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

    public func clearError() {
        errorMessage = nil
    }

    public func openProject(at url: URL) {
        do {
            let loaded = try openProjectUseCase.execute(url: url)
            project = loaded
            projectURL = url
            selectedUnitID = loaded.units.first?.id
            statusMessage = "Opened \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not open project: \(error.localizedDescription). Check that the JSON file is valid and try again."
        }
    }

    public func saveProject(at url: URL) {
        do {
            let saved = try saveProjectUseCase.execute(project: project, url: url)
            project = saved
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
}
