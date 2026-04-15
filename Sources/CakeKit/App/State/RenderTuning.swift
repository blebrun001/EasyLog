import Foundation

/// Centralized tuning knobs for rendering, refresh and caching behavior.
public struct RenderTuning: Sendable, Hashable {
    public var minZoom: Double
    public var maxZoom: Double
    public var defaultZoom: Double
    public var fitWidthVisualBoost: Double
    public var maxRenderScale: Double
    public var resizeDebounceNanoseconds: UInt64
    public var colorPresetPersistNanoseconds: UInt64
    public var rasterCacheMaxBytes: Int

    public init(
        minZoom: Double = 0.5,
        maxZoom: Double = 2.5,
        defaultZoom: Double = 1.0,
        fitWidthVisualBoost: Double = 1.12,
        maxRenderScale: Double = 6.0,
        resizeDebounceNanoseconds: UInt64 = 120_000_000,
        colorPresetPersistNanoseconds: UInt64 = 300_000_000,
        rasterCacheMaxBytes: Int = 160 * 1024 * 1024
    ) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.defaultZoom = defaultZoom
        self.fitWidthVisualBoost = fitWidthVisualBoost
        self.maxRenderScale = maxRenderScale
        self.resizeDebounceNanoseconds = resizeDebounceNanoseconds
        self.colorPresetPersistNanoseconds = colorPresetPersistNanoseconds
        self.rasterCacheMaxBytes = max(rasterCacheMaxBytes, 4 * 1024 * 1024)
    }

    public static let `default` = RenderTuning()
}
