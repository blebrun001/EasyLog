import Foundation

/// Encapsulates refresh trigger priority and synthetic-availability rules.
public struct SceneRefreshService {
    public init() {}

    public func mergedTrigger(current: SceneRefreshTrigger, incoming: SceneRefreshTrigger) -> SceneRefreshTrigger {
        switch (current, incoming) {
        case (.structural, _):
            return .structural
        case (_, .structural):
            return .structural
        case (.slider, .textInput):
            return .slider
        default:
            return incoming
        }
    }

    public func canOpenSynthetic(logs: [Project]) -> Bool {
        logs.count >= 2 && logs.allSatisfy { $0.settings.zeroLevelAltitudeMeters != nil }
    }
}
