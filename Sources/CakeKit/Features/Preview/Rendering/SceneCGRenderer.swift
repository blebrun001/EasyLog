import AppKit

public enum SceneCGRenderer {
    public static func draw(scene: RenderScene, in context: CGContext) {
        let canvasRect = CGRect(x: 0, y: 0, width: scene.canvasSize.width, height: scene.canvasSize.height)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(canvasRect)

        if scene.showsGrid {
            drawGrid(scene: scene, in: context)
        }
        drawUnits(scene: scene, in: context)
        drawScale(scene: scene, in: context)
        drawLegend(scene: scene, in: context)
        drawHeader(scene: scene, in: context)
    }

    public static func drawSymbolPattern(_ symbol: SymbolPattern, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        context.setFillColor(NSColor.black.withAlphaComponent(0.30).cgColor)

        switch symbol {
        case .sandstone:
            drawDiagonal(spacing: 10, rect: rect, context: context, forward: true)
        case .mudstone:
            drawHorizontal(spacing: 8, rect: rect, context: context)
        case .shale:
            drawHorizontal(spacing: 5, rect: rect, context: context)
            drawDiagonal(spacing: 20, rect: rect, context: context, forward: true)
        case .limestone:
            drawBrick(spacing: 12, rect: rect, context: context)
        case .dolostone:
            drawBrick(spacing: 10, rect: rect, context: context)
            drawDiagonal(spacing: 24, rect: rect, context: context, forward: true)
        case .conglomerate:
            drawPebbles(rect: rect, context: context)
        case .siltstone:
            drawDots(spacing: 10, rect: rect, context: context)
        case .claystone:
            drawHorizontal(spacing: 4, rect: rect, context: context)
        case .marl:
            drawDots(spacing: 11, rect: rect, context: context)
            drawHorizontal(spacing: 9, rect: rect, context: context)
        case .chert:
            drawCross(spacing: 10, rect: rect, context: context)
        case .coal:
            drawCross(spacing: 6, rect: rect, context: context)
            drawHorizontal(spacing: 3, rect: rect, context: context)
        case .evaporite:
            drawDiagonal(spacing: 12, rect: rect, context: context, forward: true)
            drawDiagonal(spacing: 12, rect: rect, context: context, forward: false)
        case .fallback:
            drawDiagonal(spacing: 14, rect: rect, context: context, forward: true)
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
                    drawSymbolPattern(unit.symbol, in: rect, context: context)
                }
            } else {
                drawSymbolPattern(unit.symbol, in: rect, context: context)
            }
            drawPointFeatures(unit.pointFeatures, clippedTo: rect, context: context)

            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(1.2)
            context.stroke(rect)

            let label = "\(unit.name) (\(format(unit.thickness)) m)"
            drawText(
                label,
                at: CGPoint(x: rect.maxX + 14, y: rect.midY - 6),
                size: scene.baseFontSize,
                context: context
            )
            
            // Draw grain size label if available
            if let grainSizeLabel = unit.grainSize?.label {
                drawText(
                    grainSizeLabel,
                    at: CGPoint(x: rect.maxX + 14, y: rect.midY + 8), // Positioned just below the main label
                    size: scene.baseFontSize - 2,
                    context: context,
                    bold: false
                )
            }
        }
    }

    private static func drawScale(scene: RenderScene, in context: CGContext) {
        let axisX = scene.logColumnRect.x - 28
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: axisX, y: scene.logColumnRect.y))
        context.addLine(to: CGPoint(x: axisX, y: scene.logColumnRect.y + scene.logColumnRect.height))
        context.strokePath()

        for tick in scene.ticks {
            context.move(to: CGPoint(x: axisX - 6, y: tick.y))
            context.addLine(to: CGPoint(x: axisX + 6, y: tick.y))
            context.strokePath()
            drawText(format(tick.depth), at: CGPoint(x: axisX - 50, y: tick.y - 5), size: scene.baseFontSize - 1, context: context)
        }
        drawText("Depth (m)", at: CGPoint(x: axisX - 58, y: scene.logColumnRect.y - 24), size: scene.baseFontSize, context: context)
    }

    private static func drawLegend(scene: RenderScene, in context: CGContext) {
        let originX = scene.logColumnRect.x + scene.logColumnRect.width + 170
        var originY = scene.logColumnRect.y + 10
        drawText("Legend", at: CGPoint(x: originX, y: originY - 22), size: scene.baseFontSize + 1, context: context, bold: true)

        for item in scene.legend {
            let swatch = CGRect(x: originX, y: originY, width: 28, height: 18)
            drawLegendSwatch(item: item, in: swatch, context: context, symbolScale: scene.symbolScale)
            drawText(item.label, at: CGPoint(x: originX + 36, y: originY + 3), size: scene.baseFontSize - 1, context: context)
            originY += 26
        }
    }

    private static func drawPointFeatures(_ pointFeatures: [RenderedPointFeature], clippedTo rect: CGRect, context: CGContext) {
        context.saveGState()
        context.clip(to: rect)
        for pointFeature in pointFeatures {
            drawPointSymbol(
                pointFeature.symbol,
                center: CGPoint(x: pointFeature.centerX, y: pointFeature.centerY),
                size: CGFloat(pointFeature.size),
                context: context
            )
        }
        context.restoreGState()
    }

    private static func drawLegendSwatch(item: LegendItem, in rect: CGRect, context: CGContext, symbolScale: Double) {
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        if let pointSymbol = item.pointSymbol {
            drawPointSymbol(pointSymbol, center: CGPoint(x: rect.midX, y: rect.midY), size: 8, context: context)
        } else if let code = item.usgsSymbolCode {
            if !USGSEPSSymbolRenderer.drawSymbol(code: code, in: rect, context: context, symbolScale: symbolScale) {
                drawSymbolPattern(item.symbol, in: rect, context: context)
            }
        } else {
            drawSymbolPattern(item.symbol, in: rect, context: context)
        }
        context.setStrokeColor(NSColor.black.cgColor)
        context.stroke(rect)
    }

    public static func drawPointSymbol(_ symbol: PointFeatureSymbol, center: CGPoint, size: CGFloat, context: CGContext) {
        let half = size / 2
        context.saveGState()
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.88).cgColor)
        context.setFillColor(NSColor.white.withAlphaComponent(0.95).cgColor)
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

    private static func drawHeader(scene: RenderScene, in context: CGContext) {
        drawText("Stratigraphic Log", at: CGPoint(x: scene.logColumnRect.x, y: 34), size: scene.baseFontSize + 4, context: context, bold: true)
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

    private static func drawDots(spacing: CGFloat, rect: CGRect, context: CGContext) {
        let radius: CGFloat = 1.2
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

    private static func drawPebbles(rect: CGRect, context: CGContext) {
        let step: CGFloat = 13
        let radius: CGFloat = 3.2
        var y = rect.minY + 6
        while y < rect.maxY {
            var x = rect.minX + 8
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

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
