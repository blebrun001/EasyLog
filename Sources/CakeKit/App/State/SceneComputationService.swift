import Foundation

/// Async scene computation actor to keep heavy scene building off the main actor.
public actor SceneComputationService {
    public struct SceneComputationResult: Sendable {
        public let scene: RenderScene
        public let validationIssues: [ValidationIssue]
        public let visibleUSGSCodes: [Int]

        public init(scene: RenderScene, validationIssues: [ValidationIssue], visibleUSGSCodes: [Int]) {
            self.scene = scene
            self.validationIssues = validationIssues
            self.visibleUSGSCodes = visibleUSGSCodes
        }
    }

    private let renderer: any LogRenderer

    public init(renderer: any LogRenderer) {
        self.renderer = renderer
    }

    public func computeScene(project: Project) -> SceneComputationResult {
        let scene = renderer.makeScene(project: project)
        let validationIssues = ProjectValidator.validate(project)
        let visibleCodes = Array(
            Set(scene.units.compactMap(\.usgsSymbolCode) + scene.legend.compactMap(\.usgsSymbolCode))
        ).sorted()
        return SceneComputationResult(
            scene: scene,
            validationIssues: validationIssues,
            visibleUSGSCodes: visibleCodes
        )
    }

    public func computeSynthetic(logs: [Project], selectedLogIndex: Int) -> SyntheticComparisonScene {
        guard logs.count >= 2 else { return .empty }
        guard logs.allSatisfy({ $0.settings.zeroLevelAltitudeMeters != nil }) else { return .empty }
        return SyntheticComparisonSceneBuilder.make(
            logs: logs,
            selectedLogIndex: selectedLogIndex,
            renderer: renderer
        )
    }
}

extension SceneComputationService: SceneComputing {}
