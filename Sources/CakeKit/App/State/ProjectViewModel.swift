import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
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
    private let addUnitUseCase = AddUnitUseCase()
    private let deleteSelectedUnitUseCase = DeleteSelectedUnitUseCase()
    private let moveSelectedUnitUseCase = MoveSelectedUnitUseCase()
    private var cancellables = Set<AnyCancellable>()

    public init(
        project: Project = .sample,
        renderer: LogRenderer = CakeRenderer(),
        store: ProjectStore = JSONProjectStore(),
        exporter: Exporter = CompositeExporter()
    ) {
        self.project = project
        self.renderer = renderer
        self.openProjectUseCase = OpenProjectUseCase(store: store)
        self.saveProjectUseCase = SaveProjectUseCase(store: store)
        self.exportProjectUseCase = ExportProjectUseCase(exporter: exporter)
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

    public func moveSelectedUnitUp() {
        moveSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID, direction: .up)
    }

    public func moveSelectedUnitDown() {
        moveSelectedUnitUseCase.execute(project: &project, selectedUnitID: selectedUnitID, direction: .down)
    }

    public func newProject() {
        project = Project()
        selectedUnitID = nil
        projectURL = nil
        statusMessage = "New project"
        errorMessage = nil
    }

    public func openProjectViaPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(url: url)
    }

    public func saveProjectViaPanelIfNeeded() {
        if let existingURL = projectURL {
            saveProject(url: existingURL)
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "cake-project.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveProject(url: url)
    }

    public func exportViaPanel(format: ExportFormat, dpi: Double = 300) {
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
        guard panel.runModal() == .OK, let url = panel.url else { return }
        export(url: url, format: format, dpi: dpi)
    }

    public func clearError() {
        errorMessage = nil
    }

    private func openProject(url: URL) {
        do {
            let loaded = try openProjectUseCase.execute(url: url)
            project = loaded
            projectURL = url
            selectedUnitID = loaded.units.first?.id
            statusMessage = "Opened \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not open project: \(error.localizedDescription)"
        }
    }

    private func saveProject(url: URL) {
        do {
            let saved = try saveProjectUseCase.execute(project: project, url: url)
            project = saved
            projectURL = url
            statusMessage = "Saved \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not save project: \(error.localizedDescription)"
        }
    }

    private func export(url: URL, format: ExportFormat, dpi: Double) {
        do {
            try exportProjectUseCase.execute(scene: scene, url: url, format: format, dpi: dpi)
            statusMessage = "Exported \(url.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = "Could not export file: \(error.localizedDescription)"
        }
    }
}
