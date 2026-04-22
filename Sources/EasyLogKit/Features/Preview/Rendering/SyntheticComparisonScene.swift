import AppKit
import Foundation

/// One rendered log column in the synthetic multi-log comparison view.
public struct SyntheticLogColumn: Hashable, Sendable {
    public var logIndex: Int
    public var x: Double
    public var width: Double
    public var units: [RenderedUnit]

    public init(logIndex: Int, x: Double, width: Double, units: [RenderedUnit]) {
        self.logIndex = logIndex
        self.x = x
        self.width = width
        self.units = units
    }
}

/// Immutable render snapshot for side-by-side multi-log altitude comparison.
public struct SyntheticComparisonScene: Hashable, Sendable {
    public var canvasSize: CGSizeDTO
    public var columns: [SyntheticLogColumn]
    public var legend: [LegendItem]
    public var ticks: [ScaleTick]
    public var baseFontSize: Double
    public var symbolScale: Double
    public var pointFeatureIconSize: Double
    public var depthScaleUnit: DepthScaleUnit
    public var axisX: Double
    public var logsTopY: Double
    public var logsBottomY: Double
    public var maxAltitudeMeters: Double
    public var minAltitudeMeters: Double
    public var showsGrid: Bool

    public init(
        canvasSize: CGSizeDTO,
        columns: [SyntheticLogColumn],
        legend: [LegendItem],
        ticks: [ScaleTick],
        baseFontSize: Double,
        symbolScale: Double,
        pointFeatureIconSize: Double,
        depthScaleUnit: DepthScaleUnit,
        axisX: Double,
        logsTopY: Double,
        logsBottomY: Double,
        maxAltitudeMeters: Double,
        minAltitudeMeters: Double,
        showsGrid: Bool
    ) {
        self.canvasSize = canvasSize
        self.columns = columns
        self.legend = legend
        self.ticks = ticks
        self.baseFontSize = baseFontSize
        self.symbolScale = symbolScale
        self.pointFeatureIconSize = pointFeatureIconSize
        self.depthScaleUnit = depthScaleUnit
        self.axisX = axisX
        self.logsTopY = logsTopY
        self.logsBottomY = logsBottomY
        self.maxAltitudeMeters = maxAltitudeMeters
        self.minAltitudeMeters = minAltitudeMeters
        self.showsGrid = showsGrid
    }

    public static var empty: SyntheticComparisonScene {
        SyntheticComparisonScene(
            canvasSize: CGSizeDTO(width: 1200, height: 760),
            columns: [],
            legend: [],
            ticks: [],
            baseFontSize: 12,
            symbolScale: 1.0,
            pointFeatureIconSize: 8.0,
            depthScaleUnit: .meter,
            axisX: 70,
            logsTopY: 70,
            logsBottomY: 680,
            maxAltitudeMeters: 0,
            minAltitudeMeters: -1,
            showsGrid: false
        )
    }
}

enum SyntheticComparisonSceneBuilder {
    private static let topMargin = 70.0
    private static let bottomMargin = 60.0
    private static let leftMargin = 80.0
    private static let columnSpacing = 36.0
    private static let minLegendRightMargin = 260.0
    private static let legendTrailingPadding = 24.0
    private static let measuredTextWidthCache = TextWidthCache()

    static func make(
        logs: [Project],
        selectedLogIndex: Int,
        renderer: LogRenderer
    ) -> SyntheticComparisonScene {
        guard !logs.isEmpty else { return .empty }
        let clampedSelectedIndex = min(max(selectedLogIndex, 0), logs.count - 1)
        let referenceLog = logs[clampedSelectedIndex]
        let depthUnit = referenceLog.settings.depthScaleUnit
        let verticalScale = max(referenceLog.settings.verticalScale, 0.001)
        let baseFontSize = referenceLog.settings.baseFontSize
        let symbolScale = referenceLog.settings.symbolScale
        let pointFeatureIconSize = referenceLog.settings.pointFeatureIconSize
        let showsGrid = referenceLog.settings.showGrid

        let renderedScenes = logs.map(renderer.makeScene(project:))
        let zeroLevels = logs.map { $0.settings.zeroLevelAltitudeMeters ?? 0 }

        var globalMaxAltitude = -Double.greatestFiniteMagnitude
        var globalMinAltitude = Double.greatestFiniteMagnitude

        for (logIndex, log) in logs.enumerated() {
            let zero = zeroLevels[logIndex]
            let totalThickness = max(log.units.map(\.thickness).reduce(0, +), 0)
            globalMaxAltitude = max(globalMaxAltitude, zero)
            globalMinAltitude = min(globalMinAltitude, zero - totalThickness)
        }

        if globalMaxAltitude <= globalMinAltitude {
            globalMinAltitude = globalMaxAltitude - 1
        }

        let logsHeight = (globalMaxAltitude - globalMinAltitude) * verticalScale
        let logsBottomY = topMargin + logsHeight
        let axisX = leftMargin
        var cursorX = axisX + 30
        var syntheticColumns: [SyntheticLogColumn] = []
        var mergedLegend = Set<LegendItem>()
        var mergedLegendOrdered: [LegendItem] = []

        for (logIndex, scene) in renderedScenes.enumerated() {
            let sourceLog = logs[logIndex]
            var depthTop = 0.0
            var remappedUnits: [RenderedUnit] = []
            let sourceUnitsByID = Dictionary(uniqueKeysWithValues: scene.units.map { ($0.id, $0) })

            for unit in sourceLog.units {
                let safeThickness = max(unit.thickness, 0.01)
                let unitTopAltitude = zeroLevels[logIndex] - depthTop
                let unitBottomAltitude = zeroLevels[logIndex] - (depthTop + safeThickness)
                let y = topMargin + (globalMaxAltitude - unitTopAltitude) * verticalScale
                let height = (unitTopAltitude - unitBottomAltitude) * verticalScale
                let sourceUnit = sourceUnitsByID[unit.id]
                let width = sourceUnit?.rect.width ?? SceneLayout.grainSizeWidth(for: unit.grainSize ?? .sand)

                var remappedPoints: [RenderedPointFeature] = []
                if let sourceUnit {
                    for point in sourceUnit.pointFeatures {
                        let localX = sourceUnit.rect.width > 0 ? (point.centerX - sourceUnit.rect.x) / sourceUnit.rect.width : 0.5
                        let localY = sourceUnit.rect.height > 0 ? (point.centerY - sourceUnit.rect.y) / sourceUnit.rect.height : 0.5
                        remappedPoints.append(
                            RenderedPointFeature(
                                type: point.type,
                                iconToken: point.iconToken,
                                symbol: point.symbol,
                                colorHex: point.colorHex,
                                centerX: cursorX + localX * width,
                                centerY: y + localY * height,
                                size: point.size
                            )
                        )
                    }
                }

                remappedUnits.append(
                    RenderedUnit(
                        id: unit.id,
                        name: unit.name,
                        thickness: unit.thickness,
                        lithology: unit.lithologyLabel,
                        symbol: sourceUnit?.symbol ?? SymbologyLibrary.style(forUSGSCode: unit.usgsLithologyCode).symbol,
                        usgsSymbolCode: sourceUnit?.usgsSymbolCode ?? unit.usgsLithologyCode,
                        fillHex: sourceUnit?.fillHex ?? SymbologyLibrary.style(forUSGSCode: unit.usgsLithologyCode).fillHex,
                        rect: RectD(x: cursorX, y: y, width: width, height: height),
                        grainSize: unit.grainSize,
                        pointFeatures: remappedPoints
                    )
                )
                depthTop += safeThickness
            }

            let columnWidth = remappedUnits.map { $0.rect.width }.max() ?? SceneLayout.grainSizeWidth(for: .sand)
            syntheticColumns.append(
                SyntheticLogColumn(
                    logIndex: logIndex,
                    x: cursorX,
                    width: columnWidth,
                    units: remappedUnits
                )
            )
            cursorX += columnWidth + columnSpacing

            for item in scene.legend where mergedLegend.insert(item).inserted {
                mergedLegendOrdered.append(item)
            }
        }

        let tickStep = preferredTickStepMeters(
            altitudeRangeMeters: max(globalMaxAltitude - globalMinAltitude, 0.01),
            unit: depthUnit,
            verticalScale: verticalScale
        )
        let firstTickAltitude = floor(globalMinAltitude / tickStep) * tickStep
        let lastTickAltitude = ceil(globalMaxAltitude / tickStep) * tickStep
        var ticks: [ScaleTick] = []
        var tickAltitude = firstTickAltitude
        while tickAltitude <= lastTickAltitude + 0.000_001 {
            let y = topMargin + (globalMaxAltitude - tickAltitude) * verticalScale
            let depthFromZero = globalMaxAltitude - tickAltitude
            ticks.append(ScaleTick(depth: depthFromZero, y: y))
            tickAltitude += tickStep
        }

        let legendRequiredRightMargin = max(
            minLegendRightMargin,
            requiredRightMarginForLegend(
                legend: mergedLegendOrdered,
                baseFontSize: baseFontSize
            )
        )
        let canvasWidth = cursorX + legendRequiredRightMargin
        let canvasHeight = logsBottomY + bottomMargin

        return SyntheticComparisonScene(
            canvasSize: CGSizeDTO(width: canvasWidth, height: canvasHeight),
            columns: syntheticColumns,
            legend: mergedLegendOrdered,
            ticks: ticks,
            baseFontSize: baseFontSize,
            symbolScale: symbolScale,
            pointFeatureIconSize: pointFeatureIconSize,
            depthScaleUnit: depthUnit,
            axisX: axisX,
            logsTopY: topMargin,
            logsBottomY: logsBottomY,
            maxAltitudeMeters: globalMaxAltitude,
            minAltitudeMeters: globalMinAltitude,
            showsGrid: showsGrid
        )
    }

    private static func preferredTickStepMeters(
        altitudeRangeMeters: Double,
        unit: DepthScaleUnit,
        verticalScale: Double
    ) -> Double {
        let baseStep: Double
        switch unit {
        case .meter:
            switch altitudeRangeMeters {
            case 0..<10: baseStep = 1
            case 10..<30: baseStep = 2
            case 30..<80: baseStep = 5
            default: baseStep = 10
            }
        case .centimeter:
            switch altitudeRangeMeters {
            case 0..<1: baseStep = 0.1
            case 1..<3: baseStep = 0.2
            case 3..<8: baseStep = 0.5
            default: baseStep = 1
            }
        case .millimeter:
            switch altitudeRangeMeters {
            case 0..<0.5: baseStep = 0.02
            case 0.5..<1.5: baseStep = 0.05
            case 1.5..<4: baseStep = 0.1
            default: baseStep = 0.2
            }
        }

        let minTickSpacingPixels = 20.0
        let minStepForSpacing = minTickSpacingPixels / max(verticalScale, 0.001)
        if baseStep >= minStepForSpacing {
            return baseStep
        }

        let candidates: [Double]
        switch unit {
        case .meter:
            candidates = [1, 2, 5, 10, 20, 50]
        case .centimeter:
            candidates = [0.1, 0.2, 0.5, 1, 2, 5]
        case .millimeter:
            candidates = [0.02, 0.05, 0.1, 0.2, 0.5, 1, 2]
        }

        return candidates.first(where: { $0 >= minStepForSpacing }) ?? candidates.last ?? baseStep
    }

    private static func requiredRightMarginForLegend(legend: [LegendItem], baseFontSize: Double) -> Double {
        let labelFontSize = max(baseFontSize - 1, 1)
        let titleWidth = measuredTextWidth(SceneLayout.legendTitle(), fontSize: baseFontSize + 1, bold: true)
        let maxLabelWidth = legend
            .map { measuredTextWidth($0.label, fontSize: labelFontSize, bold: false) }
            .max() ?? 0
        let titleRequired = SceneLayout.legendOffsetFromLog + titleWidth + legendTrailingPadding
        let labelsRequired = SceneLayout.legendOffsetFromLog + SceneLayout.legendTextOffset + maxLabelWidth + legendTrailingPadding
        return max(titleRequired, labelsRequired)
    }

    private static func measuredTextWidth(_ text: String, fontSize: Double, bold: Bool) -> Double {
        let cacheKey = "\(bold ? "b" : "r")|\(fontSize)|\(text)"
        if let cached = measuredTextWidthCache.value(for: cacheKey) {
            return cached
        }

        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = NSString(string: text).size(withAttributes: attributes).width
        measuredTextWidthCache.insert(width, for: cacheKey)
        return width
    }
}
