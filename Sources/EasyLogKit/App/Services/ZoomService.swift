import Foundation

/// Encapsulates zoom and scale computations.
public struct ZoomService {
    public init() {}

    public func clampedZoom(_ value: Double, tuning: RenderTuning) -> Double {
        min(max(value, tuning.minZoom), tuning.maxZoom)
    }

    public func clampedAutoFitZoom(_ value: Double, tuning: RenderTuning) -> Double {
        max(value, tuning.minZoom)
    }

    public func fitScaleForWidth(
        viewportWidth: Double,
        canvasWidth: Double,
        applyingVisualBoost: Bool,
        tuning: RenderTuning
    ) -> Double {
        guard canvasWidth > 0 else { return tuning.defaultZoom }
        let base = viewportWidth / canvasWidth
        guard applyingVisualBoost, base > 1 else { return base }
        return base * tuning.fitWidthVisualBoost
    }

    public func fitScaleForHeight(viewportHeight: Double, canvasHeight: Double, tuning: RenderTuning) -> Double {
        guard canvasHeight > 0 else { return tuning.defaultZoom }
        return viewportHeight / canvasHeight
    }

    public func resolvedRenderScale(backingScale: Double, zoom: Double, tuning: RenderTuning) -> Double {
        let scale = max(backingScale, 1.0) * max(zoom, 1.0)
        return min(scale, tuning.maxRenderScale)
    }
}
