import AppKit

/// CoreGraphics renderer for `SyntheticComparisonScene`.
public enum SyntheticSceneCGRenderer {
    public static func draw(scene: SyntheticComparisonScene, in context: CGContext) {
        let canvasRect = CGRect(x: 0, y: 0, width: scene.canvasSize.width, height: scene.canvasSize.height)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)

        if scene.showsGrid {
            drawGrid(scene: scene, in: context)
        }
        drawColumns(scene: scene, in: context)
        drawScale(scene: scene, in: context)
        drawLegend(scene: scene, in: context)
    }

    private static func drawGrid(scene: SyntheticComparisonScene, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.gray.withAlphaComponent(0.12).cgColor)
        context.setLineWidth(0.6)
        let minX = scene.columns.first.map { $0.x } ?? scene.axisX + 20
        let maxX = scene.columns.last.map { $0.x + $0.width } ?? (scene.axisX + 220)
        for tick in scene.ticks {
            context.move(to: CGPoint(x: minX - 12, y: tick.y))
            context.addLine(to: CGPoint(x: maxX + 12, y: tick.y))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawColumns(scene: SyntheticComparisonScene, in context: CGContext) {
        for column in scene.columns {
            for unit in column.units {
                let rect = CGRect(x: unit.rect.x, y: unit.rect.y, width: unit.rect.width, height: unit.rect.height)
                let fill = ColorHex.cgColor(from: unit.fillHex, fallback: NSColor.lightGray.cgColor)
                context.setFillColor(fill)
                context.fill(rect)

                if let code = unit.usgsSymbolCode {
                    if !USGSEPSSymbolRenderer.drawSymbol(code: code, in: rect, context: context, symbolScale: scene.symbolScale) {
                        SceneCGRenderer.drawSymbolPattern(unit.symbol, in: rect, context: context, symbolScale: scene.symbolScale)
                    }
                } else {
                    SceneCGRenderer.drawSymbolPattern(unit.symbol, in: rect, context: context, symbolScale: scene.symbolScale)
                }

                drawPointFeatures(unit.pointFeatures, clippedTo: rect, context: context)
                context.setStrokeColor(NSColor.black.cgColor)
                context.setLineWidth(1.2)
                context.stroke(rect)
            }
        }
    }

    private static func drawScale(scene: SyntheticComparisonScene, in context: CGContext) {
        let labelFontSize = scene.baseFontSize - 2
        let titleFontSize = scene.baseFontSize - 1
        let visibleTicks = scene.ticks.filter { $0.y >= scene.logsTopY - 0.001 && $0.y <= scene.logsBottomY + 0.001 }
        let formattedTicks: [(tick: ScaleTick, isMajor: Bool, label: String, width: Double)] = visibleTicks.map { tick in
            let isMajor = SceneLayout.isMajorScaleTick(tick.depth, unit: scene.depthScaleUnit)
            let label = SceneLayout.formatScaleDepth(
                tick.depth,
                unit: scene.depthScaleUnit,
                zeroLevelAltitudeInMeters: scene.maxAltitudeMeters
            )
            let width = measuredTextWidth(label, fontSize: labelFontSize, bold: isMajor)
            return (tick: tick, isMajor: isMajor, label: label, width: width)
        }
        let maxLabelWidth = formattedTicks.map(\.width).max() ?? 0
        let depthLabelX = SceneLayout.depthLabelCenterX(
            axisX: scene.axisX,
            maxScaleLabelWidth: maxLabelWidth,
            titleFontSize: titleFontSize
        )

        context.saveGState()
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: scene.axisX, y: scene.logsTopY))
        context.addLine(to: CGPoint(x: scene.axisX, y: scene.logsBottomY))
        context.strokePath()

        for entry in formattedTicks {
            let tick = entry.tick
            let isMajor = entry.isMajor
            let halfLength = isMajor ? SceneLayout.scaleMajorTickHalfLength : SceneLayout.scaleMinorTickHalfLength
            context.setLineWidth(isMajor ? 1.1 : 0.9)
            context.move(to: CGPoint(x: scene.axisX - halfLength, y: tick.y))
            context.addLine(to: CGPoint(x: scene.axisX + halfLength, y: tick.y))
            context.strokePath()

            drawText(
                entry.label,
                at: CGPoint(x: SceneLayout.scaleLabelX(axisX: scene.axisX, labelWidth: entry.width), y: tick.y - 5),
                size: labelFontSize,
                context: context,
                bold: isMajor
            )
        }

        drawText(
            SceneLayout.scaleAxisTitle(unit: scene.depthScaleUnit, zeroLevelAltitudeInMeters: scene.maxAltitudeMeters),
            centeredAt: CGPoint(
                x: depthLabelX,
                y: scene.logsTopY + (scene.logsBottomY - scene.logsTopY) / 2
            ),
            size: titleFontSize,
            angleRadians: -.pi / 2,
            context: context
        )
        context.restoreGState()
    }

    private static func drawLegend(scene: SyntheticComparisonScene, in context: CGContext) {
        guard let firstColumn = scene.columns.first else { return }
        let maxColumnRight = scene.columns.map { $0.x + $0.width }.max() ?? (firstColumn.x + firstColumn.width)
        let originX = maxColumnRight + SceneLayout.legendOffsetFromLog
        var originY = scene.logsTopY + 10
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
            SceneCGRenderer.drawPointSymbol(
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
        let swatchFillHex = item.pointSymbol == nil ? item.fillHex : nil
        context.setFillColor(ColorHex.cgColor(from: swatchFillHex, fallback: NSColor.white.cgColor))
        context.fill(rect)
        if let pointSymbol = item.pointSymbol {
            let strokeColor = ColorHex.cgColor(from: item.pointColorHex, fallback: NSColor.black.cgColor)
            let fillColor = ColorHex.cgColor(from: item.pointColorHex, fallback: NSColor.white.cgColor)
            SceneCGRenderer.drawPointSymbol(
                pointSymbol,
                center: CGPoint(x: rect.midX, y: rect.midY),
                size: 8,
                strokeColor: strokeColor,
                fillColor: fillColor,
                context: context
            )
        } else if let code = item.usgsSymbolCode {
            if !USGSEPSSymbolRenderer.drawSymbol(code: code, in: rect, context: context, symbolScale: symbolScale) {
                SceneCGRenderer.drawSymbolPattern(item.symbol, in: rect, context: context, symbolScale: symbolScale)
            }
        } else {
            SceneCGRenderer.drawSymbolPattern(item.symbol, in: rect, context: context, symbolScale: symbolScale)
        }
        context.setStrokeColor(NSColor.black.cgColor)
        context.stroke(rect)
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

    private static func drawText(
        _ text: String,
        centeredAt center: CGPoint,
        size: Double,
        angleRadians: Double,
        context: CGContext,
        bold: Bool = false
    ) {
        context.saveGState()
        NSGraphicsContext.saveGraphicsState()

        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: angleRadians)

        let font = bold
            ? NSFont(name: "Helvetica-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
            : NSFont(name: "Helvetica", size: size) ?? NSFont.systemFont(ofSize: size)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        let measured = NSString(string: text).size(withAttributes: attributes)
        let drawPoint = CGPoint(x: -measured.width / 2, y: -measured.height / 2)

        let nsContext = NSGraphicsContext(cgContext: context, flipped: true)
        NSGraphicsContext.current = nsContext
        NSAttributedString(string: text, attributes: attributes).draw(at: drawPoint)

        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    private static func measuredTextWidth(_ text: String, fontSize: Double, bold: Bool) -> Double {
        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSString(string: text).size(withAttributes: attributes).width
    }
}
