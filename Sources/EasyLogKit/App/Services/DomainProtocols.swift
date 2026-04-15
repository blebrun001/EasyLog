import CoreGraphics
import Foundation

public protocol SceneComputing {
    func computeScene(project: Project) async -> SceneComputationService.SceneComputationResult
    func computeSynthetic(logs: [Project], selectedLogIndex: Int) async -> SyntheticComparisonScene
}

public protocol RasterCaching {
    func image(for key: SceneRasterKey) async -> CGImage?
    func insert(_ image: CGImage, for key: SceneRasterKey) async
    func removeAll() async
}

public protocol ProjectPersisting {
    func load(url: URL) throws -> ProjectDocument
    func save(_ document: ProjectDocument, to url: URL) throws
}

public protocol Exporting {
    func export(scene: RenderScene, to url: URL, options: ExportOptions) throws
}
