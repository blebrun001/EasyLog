import Foundation
import AppKit

/// Main scene builder that maps `Project` domain data to draw-ready geometry.
public struct EasyLogRenderer: LogRenderer {
    public init() {}

    private let minimumRightMargin = 120.0
    private let legendTrailingPadding = 24.0
    private static let measuredTextWidthCache = TextWidthCache()

    private struct LithologyLegendKey: Hashable {
        let label: String
        let usgsSymbolCode: Int?
        let fillHex: String
    }

    public func makeScene(project: Project) -> RenderScene {
        let margins = (top: 70.0, bottom: 60.0, left: 100.0)
        let logTitle = {
            let trimmed = project.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Stratigraphic Log" : trimmed
        }()
        let defaultWidth = SceneLayout.grainSizeWidth(for: .sand)
        let totalThickness = max(project.units.map(\.thickness).reduce(0, +), 0.01)

        // Determine widths per unit based on grainSize or default
        var unitWidths: [Double] = []
        for unit in project.units {
            if let grainSize = unit.grainSize {
                unitWidths.append(SceneLayout.grainSizeWidth(for: grainSize))
            } else {
                unitWidths.append(defaultWidth)
            }
        }

        // The widest unit width determines the logWidth
        let logWidth = unitWidths.max() ?? defaultWidth
        let logX = margins.left
        var renderedUnits: [RenderedUnit] = []
        var legendOrder: [LegendItem] = []
        var pointLegendOrder: [LegendItem] = []
        var seenPointTypes = Set<PointFeatureType>()
        var seenLithologyLegendKeys = Set<LithologyLegendKey>()
        var seenPointLegendLabels = Set<String>()
        var yCursor = margins.top

        for (index, unit) in project.units.enumerated() {
            let safeThickness = max(unit.thickness, 0.01)
            let height = safeThickness * project.settings.verticalScale
            let usgsCode = unit.usgsLithologyCode
            let style = SymbologyLibrary.style(forUSGSCode: usgsCode)
            let resolvedFill = ColorHex.normalizedHex(unit.lithologyColorHex) ?? style.fillHex
            let width = unitWidths[index]
            let rect = RectD(x: logX, y: yCursor, width: width, height: height)
            let renderedPointFeatures = makeRenderedPointFeatures(
                for: unit.pointFeatures,
                in: rect,
                unitID: unit.id,
                settings: project.settings
            )
            renderedUnits.append(
                RenderedUnit(
                    id: unit.id,
                    name: unit.name,
                    thickness: unit.thickness,
                    lithology: unit.lithologyLabel,
                    symbol: style.symbol,
                    usgsSymbolCode: usgsCode,
                    fillHex: resolvedFill,
                    rect: rect,
                    grainSize: unit.grainSize,
                    pointFeatures: renderedPointFeatures
                )
            )

            let legendBaseLabel = SymbologyLibrary.label(forUSGSCode: usgsCode)
            let label: String
            if project.settings.showUSGSCodesInLithologyLabels {
                label = "\(legendBaseLabel) (\(usgsCode))"
            } else {
                label = legendBaseLabel
            }
            let symbolLabel = label
            let key = LithologyLegendKey(label: symbolLabel, usgsSymbolCode: usgsCode, fillHex: resolvedFill)
            let item = LegendItem(
                label: symbolLabel,
                symbol: style.symbol,
                usgsSymbolCode: usgsCode,
                fillHex: resolvedFill
            )
            if seenLithologyLegendKeys.insert(key).inserted {
                legendOrder.append(item)
            }

            for pointFeature in unit.pointFeatures {
                if seenPointTypes.insert(pointFeature.type).inserted {
                    let item = LegendItem(
                        label: "\(pointFeature.type.categoryLabel): \(pointFeature.type.label)",
                        symbol: .fallback,
                        pointIconToken: PointFeatureIconCatalog.token(for: pointFeature.type),
                        pointSymbol: pointFeature.type.symbol,
                        pointColorHex: pointFeature.resolvedColorHex
                    )
                    if seenPointLegendLabels.insert(item.label).inserted {
                        pointLegendOrder.append(item)
                    }
                }
            }
            yCursor += height
        }

        let tickStep = preferredTickStepMeters(
            for: totalThickness,
            unit: project.settings.depthScaleUnit,
            verticalScale: project.settings.verticalScale
        )
        let tickCount = Int((totalThickness / tickStep).rounded(.down))
        let ticks = (0...tickCount).map { index -> ScaleTick in
            let depth = Double(index) * tickStep
            return ScaleTick(depth: depth, y: margins.top + depth * project.settings.verticalScale)
        }
        let legend = legendOrder + pointLegendOrder
        let logBottom = margins.top + (totalThickness * project.settings.verticalScale)
        let naturalHeight = logBottom + margins.bottom
        let grainScaleRequiredHeight: Double = {
            guard project.settings.showGrainSizeScale else { return 0 }
            // Axis + tick labels + title under the grain-size scale must remain visible.
            let titleBaselineBelowAxis = SceneLayout.grainScaleLabelOffsetY + (project.settings.baseFontSize - 1) + 8
            let titleBottomPadding = project.settings.baseFontSize + 16
            return SceneLayout.grainScaleOffsetBelowLog + titleBaselineBelowAxis + titleBottomPadding
        }()
        let canvasHeight = max(naturalHeight, logBottom + grainScaleRequiredHeight)
        let rightMargin = max(
            minimumRightMargin,
            project.settings.showLegend
                ? requiredRightMarginForLegend(legend: legend, baseFontSize: project.settings.baseFontSize)
                : 0
        )
        let canvasWidth = logX + logWidth + rightMargin

        return RenderScene(
            title: logTitle,
            canvasSize: CGSizeDTO(width: canvasWidth, height: canvasHeight),
            logColumnRect: RectD(x: logX, y: margins.top, width: logWidth, height: totalThickness * project.settings.verticalScale),
            units: renderedUnits,
            legend: legend,
            ticks: ticks,
            baseFontSize: project.settings.baseFontSize,
            showsGrid: project.settings.showGrid,
            showsLegend: project.settings.showLegend,
            showsScale: project.settings.showScale,
            showsGrainSizeScale: project.settings.showGrainSizeScale,
            showsLogTitle: project.settings.showLogTitle,
            symbolScale: project.settings.symbolScale,
            pointFeatureIconSize: project.settings.pointFeatureIconSize,
            depthScaleUnit: project.settings.depthScaleUnit,
            useAbsoluteAltitude: project.settings.useAbsoluteAltitude,
            zeroLevelAltitudeMeters: project.settings.zeroLevelAltitudeMeters
        )
    }

    private func requiredRightMarginForLegend(legend: [LegendItem], baseFontSize: Double) -> Double {
        let labelFontSize = max(baseFontSize - 1, 1)
        let titleWidth = measuredTextWidth("Legend", fontSize: baseFontSize + 1, bold: true)
        let maxLabelWidth = legend
            .map { measuredTextWidth($0.label, fontSize: labelFontSize, bold: false) }
            .max() ?? 0

        let titleRequired = SceneLayout.legendOffsetFromLog + titleWidth + legendTrailingPadding
        let labelsRequired = SceneLayout.legendOffsetFromLog + SceneLayout.legendTextOffset + maxLabelWidth + legendTrailingPadding
        return max(titleRequired, labelsRequired)
    }

    private func measuredTextWidth(_ text: String, fontSize: Double, bold: Bool) -> Double {
        let cacheKey = "\(bold ? "b" : "r")|\(fontSize)|\(text)"
        if let cached = Self.measuredTextWidthCache.value(for: cacheKey) {
            return cached
        }

        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = NSString(string: text).size(withAttributes: attributes).width
        Self.measuredTextWidthCache.insert(width, for: cacheKey)
        return width
    }

    private func makeRenderedPointFeatures(
        for pointFeatures: [UnitPointFeature],
        in rect: RectD,
        unitID: UUID,
        settings: ProjectSettings
    ) -> [RenderedPointFeature] {
        var rendered: [RenderedPointFeature] = []
        let padding = min(8.0, max(2.0, min(rect.width, rect.height) * 0.1))
        let requestedSize = min(
            max(settings.pointFeatureIconSize, ProjectSettings.pointFeatureIconSizeRange.lowerBound),
            ProjectSettings.pointFeatureIconSizeRange.upperBound
        )
        let maxSizeForUnit = max(min(rect.width, rect.height) * 0.35, 3.0)
        let size = min(requestedSize, maxSizeForUnit)
        let usableWidth = max(rect.width - 2 * padding, 0)
        let usableHeight = max(rect.height - 2 * padding, 0)

        for (featureIndex, pointFeature) in pointFeatures.enumerated() {
            let symbolCount = countForPointFeature(density: pointFeature.density, rect: rect)
            for sampleIndex in 0..<symbolCount {
                // Seeded RNG keeps point placement stable across redraws for the same inputs.
                let seed = makeSeed(
                    unitID: unitID,
                    pointFeatureType: pointFeature.type,
                    featureIndex: featureIndex,
                    sampleIndex: sampleIndex
                )
                var generator = SplitMix64(state: seed)
                let xRand = generator.nextUnitDouble()
                let yRand = generator.nextUnitDouble()

                let x = usableWidth > 0
                    ? rect.x + padding + xRand * usableWidth
                    : rect.x + rect.width / 2
                let y = usableHeight > 0
                    ? rect.y + padding + yRand * usableHeight
                    : rect.y + rect.height / 2

                rendered.append(
                    RenderedPointFeature(
                        type: pointFeature.type,
                        iconToken: PointFeatureIconCatalog.token(for: pointFeature.type),
                        symbol: pointFeature.type.symbol,
                        colorHex: pointFeature.resolvedColorHex,
                        centerX: x,
                        centerY: y,
                        size: size
                    )
                )
            }
        }

        return rendered
    }

    private func countForPointFeature(density: Double, rect: RectD) -> Int {
        // Density maps to an area-proportional count constrained by min/max envelopes.
        let area = max(rect.width * rect.height, 1)
        let clampedDensity = min(max(density, 0), 1)
        let rate = 0.0002 + (0.0014 - 0.0002) * clampedDensity
        let scaled = Int((area * rate).rounded())
        let minCount = Int((1 + 6 * clampedDensity).rounded(.down))
        let maxCount = Int((8 + 36 * clampedDensity).rounded(.up))
        return min(max(scaled, max(minCount, 1)), max(maxCount, 1))
    }

    private func makeSeed(
        unitID: UUID,
        pointFeatureType: PointFeatureType,
        featureIndex: Int,
        sampleIndex: Int
    ) -> UInt64 {
        let unitHash = stableHash(unitID.uuidString)
        let typeHash = stableHash(pointFeatureType.rawValue)
        let featureHash = UInt64(featureIndex &* 1_048_573)
        let sampleHash = UInt64(sampleIndex &* 6_700_417)
        return unitHash ^ (typeHash &* 0x9E3779B97F4A7C15) ^ featureHash ^ sampleHash
    }

    private func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private func preferredTickStepMeters(
        for totalThickness: Double,
        unit: DepthScaleUnit,
        verticalScale: Double
    ) -> Double {
        let baseStep: Double
        switch unit {
        case .meter:
            switch totalThickness {
            case 0..<10: baseStep = 1
            case 10..<30: baseStep = 2
            case 30..<80: baseStep = 5
            default: baseStep = 10
            }
        case .centimeter:
            switch totalThickness {
            case 0..<1: baseStep = 0.1
            case 1..<3: baseStep = 0.2
            case 3..<8: baseStep = 0.5
            default: baseStep = 1
            }
        case .millimeter:
            switch totalThickness {
            case 0..<0.5: baseStep = 0.02
            case 0.5..<1.5: baseStep = 0.05
            case 1.5..<4: baseStep = 0.1
            default: baseStep = 0.2
            }
        }

        // Keep labels readable by enforcing a minimum pixel spacing between ticks.
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
}

private struct SplitMix64 {
    var state: UInt64

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextUnitDouble() -> Double {
        let value = nextUInt64() >> 11
        return Double(value) / Double(1 << 53)
    }
}
