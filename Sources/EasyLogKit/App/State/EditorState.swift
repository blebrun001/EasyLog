import CoreGraphics
import Combine
import Foundation

@MainActor
/// State shard focused on editor/document interactions.
public final class EditorState: ObservableObject {
    @Published public var document: ProjectDocument
    @Published public var project: Project
    @Published public var selectedLogIndex: Int
    @Published public var selectedUnitID: UUID?
    @Published public var presentationState: EditorPresentationState
    @Published public var statusMessage: String
    @Published public var errorMessage: String?

    public init(
        document: ProjectDocument,
        project: Project,
        selectedLogIndex: Int,
        selectedUnitID: UUID?,
        presentationState: EditorPresentationState,
        statusMessage: String,
        errorMessage: String?
    ) {
        self.document = document
        self.project = project
        self.selectedLogIndex = selectedLogIndex
        self.selectedUnitID = selectedUnitID
        self.presentationState = presentationState
        self.statusMessage = statusMessage
        self.errorMessage = errorMessage
    }
}

@MainActor
/// State shard focused on preview rendering and zoom output.
public final class PreviewState: ObservableObject {
    @Published public var scene: RenderScene
    @Published public var syntheticScene: SyntheticComparisonScene
    @Published public var validationIssues: [ValidationIssue]
    @Published public var zoom: Double
    @Published public var zoomMode: ProjectViewModel.ZoomMode
    @Published public var isSyntheticAvailable: Bool
    @Published public var previewStaticRaster: CGImage?
    @Published public var previewOverlayRaster: CGImage?
    @Published public var syntheticStaticRaster: CGImage?
    @Published public var syntheticOverlayRaster: CGImage?
    @Published public var previewRasterScale: Double
    @Published public var syntheticRasterScale: Double

    public init(
        scene: RenderScene,
        syntheticScene: SyntheticComparisonScene,
        validationIssues: [ValidationIssue],
        zoom: Double,
        zoomMode: ProjectViewModel.ZoomMode,
        isSyntheticAvailable: Bool,
        previewRasterScale: Double,
        syntheticRasterScale: Double
    ) {
        self.scene = scene
        self.syntheticScene = syntheticScene
        self.validationIssues = validationIssues
        self.zoom = zoom
        self.zoomMode = zoomMode
        self.isSyntheticAvailable = isSyntheticAvailable
        self.previewRasterScale = previewRasterScale
        self.syntheticRasterScale = syntheticRasterScale
    }
}
