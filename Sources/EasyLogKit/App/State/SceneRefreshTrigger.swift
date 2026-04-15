import Foundation

/// Source-aware refresh policy used to debounce render recomputation.
public enum SceneRefreshTrigger: Sendable {
    case textInput
    case slider
    case structural

    var debounceNanoseconds: UInt64 {
        switch self {
        case .textInput:
            return 120_000_000
        case .slider:
            return 40_000_000
        case .structural:
            return 0
        }
    }
}
