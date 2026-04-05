import AppKit

/// CoreGraphics raster renderer for preview canvases and JPG export.
public enum SceneCGRenderer {
    public static func draw(scene: RenderScene, in context: CGContext) {
        let canvasRect = CGRect(x: 0, y: 0, width: scene.canvasSize.width, height: scene.canvasSize.height)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)

        if scene.showsGrid {
            drawGrid(scene: scene, in: context)
        }
        drawUnits(scene: scene, in: context)
        if scene.showsScale {
            drawScale(scene: scene, in: context)
        }
        if scene.showsGrainSizeScale {
            drawGrainSizeScale(scene: scene, in: context)
        }
        if scene.showsLegend {
            drawLegend(scene: scene, in: context)
        }
        if scene.showsLogTitle {
            drawHeader(scene: scene, in: context)
        }
    }

    public static func drawSymbolPattern(_ symbol: SymbolPattern, in rect: CGRect, context: CGContext, symbolScale: Double = 1.0) {
        context.saveGState()
        context.clip(to: rect)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)
        let scale = max(CGFloat(symbolScale), 0.05)

        switch symbol {
        case .sandstone:
            drawDiagonal(spacing: 10 * scale, rect: rect, context: context, forward: true)
        case .mudstone:
            drawHorizontal(spacing: 8 * scale, rect: rect, context: context)
        case .shale:
            drawHorizontal(spacing: 5 * scale, rect: rect, context: context)
            drawDiagonal(spacing: 20 * scale, rect: rect, context: context, forward: true)
        case .limestone:
            drawBrick(spacing: 12 * scale, rect: rect, context: context)
        case .dolostone:
            drawBrick(spacing: 10 * scale, rect: rect, context: context)
            drawDiagonal(spacing: 24 * scale, rect: rect, context: context, forward: true)
        case .conglomerate:
            drawPebbles(rect: rect, context: context, symbolScale: scale)
        case .siltstone:
            drawDots(spacing: 10 * scale, rect: rect, context: context, symbolScale: scale)
        case .claystone:
            drawHorizontal(spacing: 4 * scale, rect: rect, context: context)
        case .marl:
            drawDots(spacing: 11 * scale, rect: rect, context: context, symbolScale: scale)
            drawHorizontal(spacing: 9 * scale, rect: rect, context: context)
        case .chert:
            drawCross(spacing: 10 * scale, rect: rect, context: context)
        case .coal:
            drawCross(spacing: 6 * scale, rect: rect, context: context)
            drawHorizontal(spacing: 3 * scale, rect: rect, context: context)
        case .evaporite:
            drawDiagonal(spacing: 12 * scale, rect: rect, context: context, forward: true)
            drawDiagonal(spacing: 12 * scale, rect: rect, context: context, forward: false)
        case .fallback:
            drawDiagonal(spacing: 14 * scale, rect: rect, context: context, forward: true)
        }
        context.restoreGState()
    }

    private static func drawGrid(scene: RenderScene, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(0.6)
        let startX = scene.logColumnRect.x
        let endX = scene.logColumnRect.x + scene.logColumnRect.width
        for tick in scene.ticks {
            context.move(to: CGPoint(x: startX - 30, y: tick.y))
            context.addLine(to: CGPoint(x: endX + 20, y: tick.y))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawUnits(scene: RenderScene, in context: CGContext) {
        for unit in scene.units {
            let style = SymbologyLibrary.style(forLithology: unit.lithology)
            let rect = CGRect(x: unit.rect.x, y: unit.rect.y, width: unit.rect.width, height: unit.rect.height)
            let fill = ColorHex.cgColor(from: style.fillHex, fallback: NSColor.lightGray.cgColor)

            context.setFillColor(fill)
            context.fill(rect)
            if let code = unit.usgsSymbolCode {
                if !USGSEPSSymbolRenderer.drawSymbol(code: code, in: rect, context: context, symbolScale: scene.symbolScale) {
                    drawSymbolPattern(unit.symbol, in: rect, context: context, symbolScale: scene.symbolScale)
                }
            } else {
                drawSymbolPattern(unit.symbol, in: rect, context: context, symbolScale: scene.symbolScale)
            }
            drawPointFeatures(unit.pointFeatures, clippedTo: rect, context: context)

            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.2)
            context.stroke(rect)

            let label = SceneLayout.unitPrimaryLabel(unit)
            drawText(
                label,
                at: CGPoint(
                    x: rect.maxX + SceneLayout.unitLabelOffsetX,
                    y: rect.midY + SceneLayout.unitPrimaryLabelYOffset
                ),
                size: scene.baseFontSize,
                context: context
            )

            if let grainSizeLabel = SceneLayout.unitSecondaryLabel(unit) {
                drawText(
                    grainSizeLabel,
                    at: CGPoint(
                        x: rect.maxX + SceneLayout.unitLabelOffsetX,
                        y: rect.midY + SceneLayout.unitSecondaryLabelYOffset
                    ),
                    size: scene.baseFontSize - 2,
                    context: context,
                    bold: false
                )
            }
        }
    }

    private static func drawScale(scene: RenderScene, in context: CGContext) {
        let axisX = SceneLayout.scaleAxisX(scene: scene)
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: axisX, y: scene.logColumnRect.y))
        context.addLine(to: CGPoint(x: axisX, y: scene.logColumnRect.y + scene.logColumnRect.height))
        context.strokePath()

        for tick in scene.ticks {
            let isMajor = SceneLayout.isMajorScaleTick(tick.depth, unit: scene.depthScaleUnit)
            let halfLength = isMajor ? SceneLayout.scaleMajorTickHalfLength : SceneLayout.scaleMinorTickHalfLength
            context.setLineWidth(isMajor ? 1.1 : 0.9)
            context.move(to: CGPoint(x: axisX - halfLength, y: tick.y))
            context.addLine(to: CGPoint(x: axisX + halfLength, y: tick.y))
            context.strokePath()
            drawText(
                SceneLayout.formatScaleDepth(tick.depth, unit: scene.depthScaleUnit),
                at: CGPoint(x: axisX - SceneLayout.scaleLabelOffsetX, y: tick.y - 5),
                size: scene.baseFontSize - 1,
                context: context,
                bold: isMajor
            )
        }
        drawText(
            "Depth (\(scene.depthScaleUnit.symbol))",
            at: CGPoint(
                x: axisX - SceneLayout.depthLabelOffsetX,
                y: scene.logColumnRect.y - SceneLayout.depthLabelOffsetY
            ),
            size: scene.baseFontSize,
            context: context
        )
    }

    private static func drawLegend(scene: RenderScene, in context: CGContext) {
        let legendOrigin = SceneLayout.legendOrigin(scene: scene)
        let originX = legendOrigin.x
        var originY = legendOrigin.y
        drawText("Legend", at: CGPoint(x: originX, y: originY - 22), size: scene.baseFontSize + 1, context: context, bold: true)

        for item in scene.legend {
            let swatch = CGRect(x: originX, y: originY, width: SceneLayout.legendSwatchWidth, height: 18)
            drawLegendSwatch(item: item, in: swatch, context: context, symbolScale: scene.symbolScale)
            drawText(
                item.label,
                at: CGPoint(x: originX + SceneLayout.legendTextOffset, y: originY + 3),
                size: scene.baseFontSize - 1,
                context: context
            )
            originY += SceneLayout.legendRowHeight
        }
    }

    private static func drawPointFeatures(_ pointFeatures: [RenderedPointFeature], clippedTo rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        for pointFeature in pointFeatures {
            let strokeColor = ColorHex.cgColor(from: pointFeature.colorHex, fallback: NSColor.black.cgColor)
            let fillColor = ColorHex.cgColor(from: pointFeature.colorHex, fallback: NSColor.white.cgColor)
            drawPointSymbol(
                pointFeature.symbol,
                center: CGPoint(x: pointFeature.centerX, y: pointFeature.centerY),
                size: CGFloat(pointFeature.size),
                strokeColor: strokeColor,
                fillColor: fillColor,
                context: context
            )
        }
        context.restoreGState()
    }

    private static func drawLegendSwatch(item: LegendItem, in rect: CGRect, context: CGContext, symbolScale: Double) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        if let pointSymbol = item.pointSymbol {
            let strokeColor = ColorHex.cgColor(from: item.pointColorHex, fallback: NSColor.black.cgColor)
            let fillColor = ColorHex.cgColor(from: item.pointColorHex, fallback: NSColor.white.cgColor)
            drawPointSymbol(
                pointSymbol,
                center: CGPoint(x: rect.midX, y: rect.midY),
                size: 8,
                strokeColor: strokeColor,
                fillColor: fillColor,
                context: context
            )
        } else if let code = item.usgsSymbolCode {
            if !USGSEPSSymbolRenderer.drawSymbol(code: code, in: rect, context: context, symbolScale: symbolScale) {
                drawSymbolPattern(item.symbol, in: rect, context: context, symbolScale: symbolScale)
            }
        } else {
            drawSymbolPattern(item.symbol, in: rect, context: context, symbolScale: symbolScale)
        }
        context.setStrokeColor(NSColor.black.cgColor)
        context.stroke(rect)
    }

    public static func drawPointSymbol(
        _ symbol: PointFeatureSymbol,
        center: CGPoint,
        size: CGFloat,
        strokeColor: CGColor = NSColor.black.withAlphaComponent(0.88).cgColor,
        fillColor: CGColor = NSColor.white.withAlphaComponent(0.95).cgColor,
        context: CGContext
    ) {
        let half = size / 2
        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setFillColor(fillColor)
        context.setLineWidth(1.1)

        switch symbol {
        case .diamond:
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - half))
            context.addLine(to: CGPoint(x: center.x + half, y: center.y))
            context.addLine(to: CGPoint(x: center.x, y: center.y + half))
            context.addLine(to: CGPoint(x: center.x - half, y: center.y))
            context.closePath()
            context.drawPath(using: .fillStroke)
        case .square:
            let rect = CGRect(x: center.x - half, y: center.y - half, width: size, height: size)
            context.fill(rect)
            context.stroke(rect)
        case .triangle:
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y - half))
            context.addLine(to: CGPoint(x: center.x + half, y: center.y + half))
            context.addLine(to: CGPoint(x: center.x - half, y: center.y + half))
            context.closePath()
            context.drawPath(using: .fillStroke)
        case .circle:
            let rect = CGRect(x: center.x - half, y: center.y - half, width: size, height: size)
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        case .cross:
            context.beginPath()
            context.move(to: CGPoint(x: center.x - half, y: center.y - half))
            context.addLine(to: CGPoint(x: center.x + half, y: center.y + half))
            context.move(to: CGPoint(x: center.x + half, y: center.y - half))
            context.addLine(to: CGPoint(x: center.x - half, y: center.y + half))
            context.strokePath()
        case .plus:
            context.beginPath()
            context.move(to: CGPoint(x: center.x - half, y: center.y))
            context.addLine(to: CGPoint(x: center.x + half, y: center.y))
            context.move(to: CGPoint(x: center.x, y: center.y - half))
            context.addLine(to: CGPoint(x: center.x, y: center.y + half))
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func drawGrainSizeScale(scene: RenderScene, in context: CGContext) {
        let axisY = SceneLayout.grainScaleAxisY(scene: scene)
        let minX = scene.logColumnRect.x
        let maxX = scene.logColumnRect.x + scene.logColumnRect.width
        let labelFontSize = scene.baseFontSize - 2

        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: minX, y: axisY))
        context.addLine(to: CGPoint(x: maxX, y: axisY))
        context.strokePath()

        for mark in SceneLayout.representativeGrainScaleMarks(scene: scene) {
            context.move(to: CGPoint(x: mark.x, y: axisY))
            context.addLine(to: CGPoint(x: mark.x, y: axisY + SceneLayout.grainScaleTickLength))
            context.strokePath()
        }

        for label in grainScaleLabelPlacements(scene: scene, minX: minX, maxX: maxX, fontSize: labelFontSize) {
            drawText(
                label.label,
                at: CGPoint(x: label.drawX, y: axisY + SceneLayout.grainScaleLabelOffsetY),
                size: labelFontSize,
                context: context
            )
        }

        drawText(
            "Grain Size",
            at: CGPoint(
                x: minX,
                y: axisY - scene.baseFontSize - 4
            ),
            size: scene.baseFontSize,
            context: context,
            bold: true
        )
    }

    private struct GrainLabelPlacement {
        let label: String
        var left: Double
        let width: Double
        let priority: Int
        var visible: Bool = true

        var right: Double { left + width }
        var drawX: Double { left }
    }

    private static func grainScaleLabelPlacements(
        scene: RenderScene,
        minX: Double,
        maxX: Double,
        fontSize: Double
    ) -> [GrainLabelPlacement] {
        let marks = SceneLayout.representativeGrainScaleMarks(scene: scene)
        guard !marks.isEmpty else { return [] }
        let minGap = 8.0

        var placements: [GrainLabelPlacement] = marks.enumerated().map { index, mark in
            let width = measuredTextWidth(mark.label, fontSize: fontSize, bold: false)
            let left: Double
            if index == 0 {
                left = minX
            } else if index == marks.count - 1 {
                left = maxX - width
            } else {
                left = mark.x - width / 2
            }
            let clampedLeft = min(max(left, minX), maxX - width)
            return GrainLabelPlacement(
                label: mark.label,
                left: clampedLeft,
                width: width,
                priority: grainLabelPriority(mark.label)
            )
        }

        var safety = 0
        while safety < 12 {
            safety += 1
            let visibleIndices = placements.indices.filter { placements[$0].visible }
            var overlapFound = false
            for pair in zip(visibleIndices, visibleIndices.dropFirst()) {
                let lhs = placements[pair.0]
                let rhs = placements[pair.1]
                if lhs.right + minGap > rhs.left {
                    overlapFound = true
                    if lhs.priority < rhs.priority {
                        placements[pair.0].visible = false
                    } else if rhs.priority < lhs.priority {
                        placements[pair.1].visible = false
                    } else {
                        placements[pair.1].visible = false
                    }
                    break
                }
            }
            if !overlapFound { break }
        }

        return placements.filter(\.visible)
    }

    private static func grainLabelPriority(_ label: String) -> Int {
        switch label {
        case "Fine", "Coarse":
            return 3
        case "Silt":
            return 2
        case "Sand":
            return 1
        default:
            return 1
        }
    }

    private static func measuredTextWidth(_ text: String, fontSize: Double, bold: Bool) -> Double {
        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSString(string: text).size(withAttributes: attributes).width
    }

    private static func drawHeader(scene: RenderScene, in context: CGContext) {
        drawText(
            scene.title,
            at: CGPoint(x: scene.logColumnRect.x, y: SceneLayout.logTitleY(scene: scene)),
            size: scene.baseFontSize + 4,
            context: context,
            bold: true
        )
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        size: Double,
        context: CGContext,
        bold: Bool = false
    ) {
        context.saveGState()
        NSGraphicsContext.saveGraphicsState()
        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext

        let font = bold
            ? NSFont(name: "Helvetica-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
            : NSFont(name: "Helvetica", size: size) ?? NSFont.systemFont(ofSize: size)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)

        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    private static func drawDiagonal(spacing: CGFloat, rect: CGRect, context: CGContext, forward: Bool) {
        context.setLineWidth(0.8)
        let extent = rect.width + rect.height
        var offset = -extent
        while offset < extent {
            let start = CGPoint(x: rect.minX + offset, y: rect.minY)
            let end = CGPoint(x: rect.minX + offset + extent, y: rect.maxY)
            if forward {
                context.move(to: start)
                context.addLine(to: end)
            } else {
                context.move(to: CGPoint(x: start.x, y: rect.maxY))
                context.addLine(to: CGPoint(x: end.x, y: rect.minY))
            }
            offset += spacing
        }
        context.strokePath()
    }

    private static func drawHorizontal(spacing: CGFloat, rect: CGRect, context: CGContext) {
        context.setLineWidth(0.8)
        var y = rect.minY
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            y += spacing
        }
        context.strokePath()
    }

    private static func drawCross(spacing: CGFloat, rect: CGRect, context: CGContext) {
        drawHorizontal(spacing: spacing, rect: rect, context: context)
        context.setLineWidth(0.8)
        var x = rect.minX
        while x <= rect.maxX {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += spacing
        }
        context.strokePath()
    }

    private static func drawDots(spacing: CGFloat, rect: CGRect, context: CGContext, symbolScale: CGFloat = 1.0) {
        let radius: CGFloat = 1.2 * symbolScale
        var y = rect.minY + spacing / 2
        while y < rect.maxY {
            var x = rect.minX + spacing / 2
            while x < rect.maxX {
                context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += spacing
            }
            y += spacing
        }
    }

    private static func drawPebbles(rect: CGRect, context: CGContext, symbolScale: CGFloat = 1.0) {
        let step: CGFloat = 13 * symbolScale
        let radius: CGFloat = 3.2 * symbolScale
        var y = rect.minY + 6 * symbolScale
        while y < rect.maxY {
            var x = rect.minX + 8 * symbolScale
            while x < rect.maxX {
                context.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += step
            }
            y += step
        }
    }

    private static func drawBrick(spacing: CGFloat, rect: CGRect, context: CGContext) {
        context.setLineWidth(0.7)
        var y = rect.minY
        var row = 0
        while y <= rect.maxY {
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            let offset = row.isMultiple(of: 2) ? 0.0 : spacing / 2
            var x = rect.minX + offset
            while x <= rect.maxX {
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x, y: min(y + spacing, rect.maxY)))
                x += spacing
            }
            y += spacing
            row += 1
        }
        context.strokePath()
    }

}
