import Foundation
import AppKit

public struct CakeRenderer: LogRenderer {
    public init() {}

    private let minimumRightMargin = 260.0
    private let legendTrailingPadding = 24.0

    nonisolated(unsafe) private static let grainSizeWidthMapping: [USGSGrainSize: Double] = [
        .clay: 50,
        .silt: 70,
        .sand: 100,
        .granule: 120,
        .pebble: 140,
        .cobble: 160,
        .boulder: 180
    ]

    public func makeScene(project: Project) -> RenderScene {
        let margins = (top: 70.0, bottom: 60.0, left: 100.0)
        let logTitle = {
            let trimmed = project.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Stratigraphic Log" : trimmed
        }()
        let defaultWidth = CakeRenderer.grainSizeWidthMapping[.sand] ?? 100.0
        let totalThickness = max(project.units.map(\.thickness).reduce(0, +), 0.01)

        // Determine widths per unit based on grainSize or default
        var unitWidths: [Double] = []
        for unit in project.units {
            if let grainSize = unit.grainSize, let width = CakeRenderer.grainSizeWidthMapping[grainSize] {
                unitWidths.append(width)
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
        var seenUSGSCodes = Set<Int>()
        var seenPointTypes = Set<PointFeatureType>()
        var seenLegendLabels = Set<String>()
        var hasFallbackLegend = false
        var yCursor = margins.top

        for (index, unit) in project.units.enumerated() {
            let safeThickness = max(unit.thickness, 0.01)
            let height = safeThickness * project.settings.verticalScale
            let style = SymbologyLibrary.style(forLithology: unit.lithology)
            let usgsCode = SymbologyLibrary.usgsSymbolCode(forLithology: unit.lithology)
            let width = unitWidths[index]
            let rect = RectD(x: logX, y: yCursor, width: width, height: height)
            let renderedPointFeatures = makeRenderedPointFeatures(
                for: unit.pointFeatures,
                in: rect,
                unitID: unit.id
            )
            renderedUnits.append(
                RenderedUnit(
                    id: unit.id,
                    name: unit.name,
                    thickness: unit.thickness,
                    lithology: unit.lithology,
                    symbol: style.symbol,
                    usgsSymbolCode: usgsCode,
                    rect: rect,
                    grainSize: unit.grainSize,
                    pointFeatures: renderedPointFeatures
                )
            )

            if let usgsCode {
                if !seenUSGSCodes.contains(usgsCode) {
                    seenUSGSCodes.insert(usgsCode)
                    let item = LegendItem(label: "\(unit.lithology.capitalized) (\(usgsCode))", symbol: style.symbol, usgsSymbolCode: usgsCode)
                    if seenLegendLabels.insert(item.label).inserted {
                        legendOrder.append(item)
                    }
                }
            } else {
                if !hasFallbackLegend {
                    hasFallbackLegend = true
                    let item = LegendItem(label: unit.lithology.capitalized, symbol: style.symbol)
                    if seenLegendLabels.insert(item.label).inserted {
                        legendOrder.append(item)
                    }
                }
            }

            for pointFeature in unit.pointFeatures {
                if seenPointTypes.insert(pointFeature.type).inserted {
                    let item = LegendItem(
                        label: "\(pointFeature.type.categoryLabel): \(pointFeature.type.label)",
                        symbol: .fallback,
                        pointSymbol: pointFeature.type.symbol
                    )
                    if seenLegendLabels.insert(item.label).inserted {
                        pointLegendOrder.append(item)
                    }
                }
            }
            yCursor += height
        }

        let tickStep = preferredTickStepMeters(
            for: totalThickness,
            unit: project.settings.depthScaleUnit
        )
        let tickCount = Int((totalThickness / tickStep).rounded(.down))
        let ticks = (0...tickCount).map { index -> ScaleTick in
            let depth = Double(index) * tickStep
            return ScaleTick(depth: depth, y: margins.top + depth * project.settings.verticalScale)
        }
        let legend = legendOrder + pointLegendOrder
        let naturalHeight = margins.top + (totalThickness * project.settings.verticalScale) + margins.bottom
        let canvasHeight = naturalHeight
        let rightMargin = max(
            minimumRightMargin,
            requiredRightMarginForLegend(legend: legend, baseFontSize: project.settings.baseFontSize)
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
            symbolScale: project.settings.symbolScale,
            depthScaleUnit: project.settings.depthScaleUnit
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
        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSString(string: text).size(withAttributes: attributes).width
    }

    private func makeRenderedPointFeatures(
        for pointFeatures: [UnitPointFeature],
        in rect: RectD,
        unitID: UUID
    ) -> [RenderedPointFeature] {
        var rendered: [RenderedPointFeature] = []
        let padding = min(8.0, max(2.0, min(rect.width, rect.height) * 0.1))
        let size = min(7.0, max(4.0, min(rect.width, rect.height) * 0.15))
        let usableWidth = max(rect.width - 2 * padding, 0)
        let usableHeight = max(rect.height - 2 * padding, 0)

        for (featureIndex, pointFeature) in pointFeatures.enumerated() {
            let symbolCount = countForPointFeature(density: pointFeature.density, rect: rect)
            for sampleIndex in 0..<symbolCount {
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
                        symbol: pointFeature.type.symbol,
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

    private func preferredTickStepMeters(for totalThickness: Double, unit: DepthScaleUnit) -> Double {
        switch unit {
        case .meter:
            switch totalThickness {
            case 0..<10: return 1
            case 10..<30: return 2
            case 30..<80: return 5
            default: return 10
            }
        case .centimeter:
            switch totalThickness {
            case 0..<1: return 0.1
            case 1..<3: return 0.2
            case 3..<8: return 0.5
            default: return 1
            }
        case .millimeter:
            switch totalThickness {
            case 0..<0.5: return 0.02
            case 0.5..<1.5: return 0.05
            case 1.5..<4: return 0.1
            default: return 0.2
            }
        }
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
