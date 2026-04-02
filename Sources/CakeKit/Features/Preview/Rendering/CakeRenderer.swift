import Foundation

public struct CakeRenderer: LogRenderer {
    public init() {}

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
        let margins = (top: 70.0, right: 260.0, bottom: 60.0, left: 100.0)
        let basePage = project.settings.pageSize.canvasSize
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
        let naturalHeight = margins.top + (totalThickness * project.settings.verticalScale) + margins.bottom
        let canvasHeight = max(basePage.height, naturalHeight)
        let canvasWidth = max(basePage.width, logX + logWidth + margins.right)

        var renderedUnits: [RenderedUnit] = []
        var legendOrder: [LegendItem] = []
        var seenSymbols = Set<SymbolPattern>()
        var yCursor = margins.top

        for (index, unit) in project.units.enumerated() {
            let safeThickness = max(unit.thickness, 0.01)
            let height = safeThickness * project.settings.verticalScale
            let style = SymbologyLibrary.style(forLithology: unit.lithology)
            let width = unitWidths[index]
            let rect = RectD(x: logX, y: yCursor, width: width, height: height)
            renderedUnits.append(
                RenderedUnit(
                    id: unit.id,
                    name: unit.name,
                    thickness: unit.thickness,
                    lithology: unit.lithology,
                    symbol: style.symbol,
                    rect: rect,
                    grainSize: unit.grainSize
                )
            )

            if !seenSymbols.contains(style.symbol) {
                seenSymbols.insert(style.symbol)
                legendOrder.append(LegendItem(label: unit.lithology.capitalized, symbol: style.symbol))
            }
            yCursor += height
        }

        let tickStep = preferredTickStep(for: totalThickness)
        let tickCount = Int((totalThickness / tickStep).rounded(.down))
        let ticks = (0...tickCount).map { index -> ScaleTick in
            let depth = Double(index) * tickStep
            return ScaleTick(depth: depth, y: margins.top + depth * project.settings.verticalScale)
        }

        return RenderScene(
            canvasSize: CGSizeDTO(width: canvasWidth, height: canvasHeight),
            logColumnRect: RectD(x: logX, y: margins.top, width: logWidth, height: totalThickness * project.settings.verticalScale),
            units: renderedUnits,
            legend: legendOrder,
            ticks: ticks,
            baseFontSize: project.settings.baseFontSize,
            showsGrid: project.settings.showGrid
        )
    }

    private func preferredTickStep(for totalThickness: Double) -> Double {
        switch totalThickness {
        case 0..<10: return 1
        case 10..<30: return 2
        case 30..<80: return 5
        default: return 10
        }
    }
}
