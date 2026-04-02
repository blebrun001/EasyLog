import Foundation

public enum MoveDirection {
    case up
    case down
}

public struct AddUnitUseCase {
    public init() {}

    public func execute(project: inout Project) -> UUID {
        let unit = StratigraphicUnit(
            name: "New Unit",
            thickness: 1.0,
            lithology: "Massive sand or sandstone",
            grainSize: .sand
        )
        project.units.append(unit)
        return unit.id
    }
}

public struct DeleteSelectedUnitUseCase {
    public init() {}

    public func execute(project: inout Project, selectedUnitID: UUID?) -> UUID? {
        guard
            let selectedUnitID,
            let index = project.units.firstIndex(where: { $0.id == selectedUnitID })
        else {
            return selectedUnitID
        }

        project.units.remove(at: index)
        guard !project.units.isEmpty else { return nil }
        return project.units.indices.contains(index) ? project.units[index].id : project.units.last?.id
    }
}

public struct MoveSelectedUnitUseCase {
    public init() {}

    public func execute(project: inout Project, selectedUnitID: UUID?, direction: MoveDirection) {
        guard
            let selectedUnitID,
            let index = project.units.firstIndex(where: { $0.id == selectedUnitID })
        else {
            return
        }

        switch direction {
        case .up:
            guard index > 0 else { return }
            project.units.swapAt(index, index - 1)
        case .down:
            guard index < project.units.count - 1 else { return }
            project.units.swapAt(index, index + 1)
        }
    }
}

public struct OpenProjectUseCase {
    private let store: ProjectStore

    public init(store: ProjectStore) {
        self.store = store
    }

    public func execute(url: URL) throws -> Project {
        try store.load(url: url)
    }
}

public struct SaveProjectUseCase {
    private let store: ProjectStore
    private let now: () -> Date

    public init(store: ProjectStore, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    public func execute(project: Project, url: URL) throws -> Project {
        var updated = project
        updated.metadata.updatedAt = now()
        try store.save(updated, to: url)
        return updated
    }
}

public struct ExportProjectUseCase {
    private let exporter: Exporter

    public init(exporter: Exporter) {
        self.exporter = exporter
    }

    public func execute(scene: RenderScene, url: URL, format: ExportFormat, dpi: Double) throws {
        try exporter.export(scene: scene, to: url, options: ExportOptions(format: format, dpi: dpi))
    }
}
