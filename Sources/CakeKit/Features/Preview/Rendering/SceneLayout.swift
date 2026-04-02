import Foundation

/// Shared layout constants and label formatting helpers for renderers/exporters.
public enum SceneLayout {
    public static let legendOffsetFromLog = 170.0
    public static let legendTextOffset = 36.0
    public static let legendRowHeight = 26.0
    public static let legendSwatchWidth = 28.0
    public static let unitLabelOffsetX = 14.0
    public static let unitPrimaryLabelYOffset = -6.0
    public static let unitSecondaryLabelYOffset = 8.0
    public static let scaleAxisOffsetFromLog = 28.0
    public static let scaleLabelOffsetX = 62.0
    public static let depthLabelOffsetX = 66.0
    public static let depthLabelOffsetY = 24.0
    public static let scaleMinorTickHalfLength = 4.0
    public static let scaleMajorTickHalfLength = 7.0

    public static func scaleAxisX(scene: RenderScene) -> Double {
        scene.logColumnRect.x - scaleAxisOffsetFromLog
    }

    public static func legendOrigin(scene: RenderScene) -> (x: Double, y: Double) {
        (x: scene.logColumnRect.x + scene.logColumnRect.width + legendOffsetFromLog, y: scene.logColumnRect.y + 10)
    }

    public static func unitPrimaryLabel(_ unit: RenderedUnit) -> String {
        "\(unit.name) (\(format(unit.thickness)) m)"
    }

    public static func unitSecondaryLabel(_ unit: RenderedUnit) -> String? {
        unit.grainSize?.label
    }

    public static func formatScaleDepth(_ depthInMeters: Double, unit: DepthScaleUnit) -> String {
        let scaled = depthInMeters * unit.multiplierFromMeters
        switch unit {
        case .meter:
            return format(scaled)
        case .centimeter, .millimeter:
            return String(Int(scaled.rounded()))
        }
    }

    public static func isMajorScaleTick(_ depthInMeters: Double, unit: DepthScaleUnit) -> Bool {
        if abs(depthInMeters) < 0.000_001 {
            return true
        }
        let interval = majorTickIntervalMeters(unit: unit)
        let remainder = depthInMeters.truncatingRemainder(dividingBy: interval)
        return abs(remainder) < 0.000_001 || abs(remainder - interval) < 0.000_001
    }

    public static func majorTickIntervalMeters(unit: DepthScaleUnit) -> Double {
        switch unit {
        case .meter:
            return 5.0
        case .centimeter:
            return 0.5
        case .millimeter:
            return 0.1
        }
    }

    public static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
