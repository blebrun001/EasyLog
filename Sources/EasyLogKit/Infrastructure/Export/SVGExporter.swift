import Foundation
import AppKit

/// Vector exporter that serializes a `RenderScene` into an editable SVG file.
public struct SVGExporter: SVGExporting {
    public init() {}

    public func export(scene: RenderScene, to url: URL, canvas: CGSizeDTO) throws {
        let usgsPatternByKey = buildUSGSPatternDefinitions(scene: scene)
        var svg = ""
        svg += """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="\(fmt(canvas.width))" height="\(fmt(canvas.height))" viewBox="0 0 \(fmt(canvas.width)) \(fmt(canvas.height))">
        """
        if scene.showsLogTitle {
            svg += """
              <title>\(xmlEscape(scene.title))</title>
            """
        }
        svg += """
          <defs>
        \(patternDefinitions(scene: scene, usgsPatternByKey: usgsPatternByKey))
          </defs>
          <rect width="100%" height="100%" fill="#ffffff"/>
        """

        if scene.showsGrid {
            let startX = scene.logColumnRect.x
            let endX = scene.logColumnRect.x + scene.logColumnRect.width
            svg += """

              <g id="grid" stroke="#808080" stroke-opacity="0.12" fill="none" stroke-width="0.6">
            """
            for tick in scene.ticks {
                svg += """

                  <line x1="\(fmt(startX - 30))" y1="\(fmt(tick.y))" x2="\(fmt(endX + 20))" y2="\(fmt(tick.y))"/>
                """
            }
            svg += """
              </g>
            """
        }

        svg += "\n  <g id=\"units\">"
        for unit in scene.units {
            let fill = unit.fillHex
            svg += """

            <g id="unit-\(unit.id.uuidString)">
              <rect x="\(fmt(unit.rect.x))" y="\(fmt(unit.rect.y))" width="\(fmt(unit.rect.width))" height="\(fmt(unit.rect.height))" fill="\(fill)" class="unit-fill"/>
              <rect x="\(fmt(unit.rect.x))" y="\(fmt(unit.rect.y))" width="\(fmt(unit.rect.width))" height="\(fmt(unit.rect.height))" fill="url(#\(patternID(symbol: unit.symbol, usgsSymbolCode: unit.usgsSymbolCode, availableUSGSKeys: usgsPatternByKey)))" class="unit-pattern"/>
            </g>
            """
            if !unit.pointFeatures.isEmpty {
                svg += """

                <g id="unit-points-\(unit.id.uuidString)">
                """
                for pointFeature in unit.pointFeatures {
                    svg += "\n\(pointFeatureElement(pointFeature))"
                }
                svg += """

                </g>
                """
            }
        }
        svg += "\n  </g>"

        svg += "\n  <g id=\"borders\" stroke=\"#111111\" fill=\"none\" stroke-width=\"1.2\">"
        for unit in scene.units {
            svg += """

            <rect x="\(fmt(unit.rect.x))" y="\(fmt(unit.rect.y))" width="\(fmt(unit.rect.width))" height="\(fmt(unit.rect.height))"/>
            """
        }
        svg += """
          </g>
        """

        svg += "\n  <g id=\"labels\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"\(fmt(scene.baseFontSize))\" fill=\"#111111\">"
        for unit in scene.units {
            let textY = unit.rect.y + unit.rect.height / 2 + SceneLayout.unitPrimaryLabelYOffset + 10
            let escaped = xmlEscape(SceneLayout.unitPrimaryLabel(unit))
            svg += """

            <text x="\(fmt(unit.rect.x + unit.rect.width + SceneLayout.unitLabelOffsetX))" y="\(fmt(textY))">\(escaped)</text>
            """
        }
        svg += "\n  </g>"

        if scene.showsScale {
            let axisX = SceneLayout.scaleAxisX(scene: scene)
            let scaleReferenceAltitude = scene.useAbsoluteAltitude ? (scene.zeroLevelAltitudeMeters ?? 0) : nil
            let labelFontSize = scene.baseFontSize - 2
            let titleFontSize = scene.baseFontSize - 1
            let formattedTicks: [(tick: ScaleTick, isMajor: Bool, label: String, width: Double)] = scene.ticks.map { tick in
                let isMajor = SceneLayout.isMajorScaleTick(tick.depth, unit: scene.depthScaleUnit)
                let label = SceneLayout.formatScaleDepth(
                    tick.depth,
                    unit: scene.depthScaleUnit,
                    zeroLevelAltitudeInMeters: scaleReferenceAltitude
                )
                let width = measuredTextWidth(label, fontSize: labelFontSize, bold: isMajor)
                return (tick: tick, isMajor: isMajor, label: label, width: width)
            }
            let maxLabelWidth = formattedTicks.map(\.width).max() ?? 0
            let depthLabelX = SceneLayout.depthLabelCenterX(
                axisX: axisX,
                maxScaleLabelWidth: maxLabelWidth,
                titleFontSize: titleFontSize
            )

            svg += """

              <g id="scale" stroke="#111111" fill="none" stroke-width="1">
                <line x1="\(fmt(axisX))" y1="\(fmt(scene.logColumnRect.y))" x2="\(fmt(axisX))" y2="\(fmt(scene.logColumnRect.y + scene.logColumnRect.height))"/>
            """
            for tick in scene.ticks {
                let isMajor = SceneLayout.isMajorScaleTick(tick.depth, unit: scene.depthScaleUnit)
                let halfLength = isMajor ? SceneLayout.scaleMajorTickHalfLength : SceneLayout.scaleMinorTickHalfLength
                let strokeWidth = isMajor ? 1.1 : 0.9
                svg += """

                    <line x1="\(fmt(axisX - halfLength))" y1="\(fmt(tick.y))" x2="\(fmt(axisX + halfLength))" y2="\(fmt(tick.y))" stroke-width="\(fmt(strokeWidth))"/>
                """
            }
            svg += "\n  </g>"

            svg += "\n  <g id=\"scale-labels\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"\(fmt(labelFontSize))\" fill=\"#111111\">"
            for entry in formattedTicks {
                let fontWeight = entry.isMajor ? "700" : "400"
                svg += """

                <text x="\(fmt(SceneLayout.scaleLabelX(axisX: axisX, labelWidth: entry.width)))" y="\(fmt(entry.tick.y + 4))" font-weight="\(fontWeight)">\(entry.label)</text>
                """
            }
            let depthLabelY = scene.logColumnRect.y + scene.logColumnRect.height / 2
            svg += """

                <text x="\(fmt(depthLabelX))" y="\(fmt(depthLabelY))" font-size="\(fmt(titleFontSize))" text-anchor="middle" dominant-baseline="middle" transform="rotate(90 \(fmt(depthLabelX)) \(fmt(depthLabelY)))">\(SceneLayout.scaleAxisTitle(unit: scene.depthScaleUnit, zeroLevelAltitudeInMeters: scaleReferenceAltitude))</text>
              </g>
            """
        }

        if scene.showsGrainSizeScale {
            let axisY = SceneLayout.grainScaleAxisY(scene: scene)
            let minX = scene.logColumnRect.x
            let maxX = scene.logColumnRect.x + scene.logColumnRect.width
            let labelFontSize = scene.baseFontSize - 3
            svg += """

              <g id="grain-size-scale" stroke="#111111" fill="none" stroke-width="1">
                <line x1="\(fmt(minX))" y1="\(fmt(axisY))" x2="\(fmt(maxX))" y2="\(fmt(axisY))"/>
            """
            for mark in SceneLayout.representativeGrainScaleMarks(scene: scene) {
                svg += """

                  <line x1="\(fmt(mark.x))" y1="\(fmt(axisY))" x2="\(fmt(mark.x))" y2="\(fmt(axisY + SceneLayout.grainScaleTickLength))"/>
                """
            }
            svg += "\n  </g>"
            svg += """

              <g id="grain-size-labels" font-family="Helvetica, Arial, sans-serif" fill="#111111">
                <text x="\(fmt(minX))" y="\(fmt(axisY + SceneLayout.grainScaleLabelOffsetY + (scene.baseFontSize - 1) + 8))" font-size="\(fmt(scene.baseFontSize - 1))">\(xmlEscape(SceneLayout.grainScaleTitle()))</text>
            """
            for label in grainScaleLabelPlacements(scene: scene, minX: minX, maxX: maxX, fontSize: labelFontSize) {
                svg += """

                <text x="\(fmt(label.drawX))" y="\(fmt(axisY + SceneLayout.grainScaleLabelOffsetY))" font-size="\(fmt(labelFontSize))">\(xmlEscape(label.label))</text>
                """
            }
            svg += """
              </g>
            """
        }

        if scene.showsLegend {
            let legendOrigin = SceneLayout.legendOrigin(scene: scene)
            let legendX = legendOrigin.x
            var legendY = legendOrigin.y
            svg += """

              <g id="legend">
                <text x="\(fmt(legendX))" y="\(fmt(legendY - 10))" font-family="Helvetica, Arial, sans-serif" font-size="\(fmt(scene.baseFontSize + 1))" font-weight="700">\(xmlEscape(SceneLayout.legendTitle()))</text>
            """
            for item in scene.legend {
                let swatchFill = xmlEscape(item.fillHex ?? "#ffffff")
                svg += """

                  <rect x="\(fmt(legendX))" y="\(fmt(legendY))" width="\(fmt(SceneLayout.legendSwatchWidth))" height="18" fill="\(swatchFill)"/>
                """
                if item.pointIconToken != nil || item.pointSymbol != nil {
                    svg += "\n\(pointLegendElement(iconToken: item.pointIconToken, symbol: item.pointSymbol, colorHex: item.pointColorHex, centerX: legendX + 14, centerY: legendY + 9, size: min(max(scene.pointFeatureIconSize, ProjectSettings.legendPointFeatureIconSizeRange.lowerBound), ProjectSettings.legendPointFeatureIconSizeRange.upperBound)))"
                } else {
                    svg += "\n  <rect x=\"\(fmt(legendX))\" y=\"\(fmt(legendY))\" width=\"\(fmt(SceneLayout.legendSwatchWidth))\" height=\"18\" fill=\"url(#\(patternID(symbol: item.symbol, usgsSymbolCode: item.usgsSymbolCode, availableUSGSKeys: usgsPatternByKey)))\"/>"
                }
                svg += """
                  <rect x="\(fmt(legendX))" y="\(fmt(legendY))" width="\(fmt(SceneLayout.legendSwatchWidth))" height="18" fill="none" stroke="#111111" stroke-width="1"/>
                  <text x="\(fmt(legendX + SceneLayout.legendTextOffset))" y="\(fmt(legendY + 13))" font-family="Helvetica, Arial, sans-serif" font-size="\(fmt(scene.baseFontSize - 1))">\(xmlEscape(item.label))</text>
                """
                legendY += SceneLayout.legendRowHeight
            }
            svg += "\n  </g>"
        }

        svg += "\n</svg>\n"

        try svg.write(to: url, atomically: true, encoding: .utf8)
    }

    private func patternDefinitions(scene: RenderScene, usgsPatternByKey: [String: String]) -> String {
        var definitions: [String] = []
        definitions.append(contentsOf: usgsPatternByKey.values.sorted())

        var fallbackSymbols = Set<SymbolPattern>()
        for unit in scene.units where patternKey(usgsSymbolCode: unit.usgsSymbolCode) == nil || usgsPatternByKey[patternKey(usgsSymbolCode: unit.usgsSymbolCode)!] == nil {
            fallbackSymbols.insert(unit.symbol)
        }
        for item in scene.legend where item.pointSymbol == nil && item.pointIconToken == nil && (patternKey(usgsSymbolCode: item.usgsSymbolCode) == nil || usgsPatternByKey[patternKey(usgsSymbolCode: item.usgsSymbolCode)!] == nil) {
            fallbackSymbols.insert(item.symbol)
        }
        definitions.append(contentsOf: fallbackSymbols.sorted(by: { $0.rawValue < $1.rawValue }).map { patternDefinition(for: $0) })
        return definitions.joined(separator: "\n")
    }

    private func buildUSGSPatternDefinitions(scene: RenderScene) -> [String: String] {
        var items = Set<String>()
        scene.units.compactMap { patternKey(usgsSymbolCode: $0.usgsSymbolCode) }.forEach { items.insert($0) }
        scene.legend.compactMap { patternKey(usgsSymbolCode: $0.usgsSymbolCode) }.forEach { items.insert($0) }

        var map: [String: String] = [:]
        for key in items.sorted() {
            let tile: (data: Data, width: Int, height: Int)?
            let tileSize: CGSizeDTO?
            if key.hasPrefix("code:"), let code = Int(key.split(separator: ":", maxSplits: 1).last ?? "") {
                tile = USGSEPSSymbolRenderer.pngTileData(for: code, maxDimension: 2048)
                tileSize = USGSEPSSymbolRenderer.tileSizePoints(for: code, symbolScale: scene.symbolScale)
            } else {
                tile = nil
                tileSize = nil
            }

            guard let tile, let tileSize else { continue }
            let safeID = key.replacingOccurrences(of: ":", with: "-")
            let id = "pattern-usgs-\(safeID)"
            let base64 = tile.data.base64EncodedString()
            let tileWidth = max(tileSize.width, 1)
            let tileHeight = max(tileSize.height, 1)
            map[key] = """
            <pattern id="\(id)" patternUnits="userSpaceOnUse" width="\(fmt(tileWidth))" height="\(fmt(tileHeight))">
              <image x="0" y="0" width="\(fmt(tileWidth))" height="\(fmt(tileHeight))" preserveAspectRatio="none" href="data:image/png;base64,\(base64)" xlink:href="data:image/png;base64,\(base64)"/>
            </pattern>
            """
        }
        return map
    }

    private func patternID(symbol: SymbolPattern, usgsSymbolCode: Int?, availableUSGSKeys: [String: String]) -> String {
        if let key = patternKey(usgsSymbolCode: usgsSymbolCode),
           availableUSGSKeys[key] != nil {
            return "pattern-usgs-\(key.replacingOccurrences(of: ":", with: "-"))"
        }
        return "pattern-\(symbol.rawValue)"
    }

    private func patternKey(usgsSymbolCode: Int?) -> String? {
        if let usgsSymbolCode {
            return "code:\(usgsSymbolCode)"
        }
        return nil
    }

    private func pointFeatureElement(_ pointFeature: RenderedPointFeature) -> String {
        pointLegendElement(
            iconToken: pointFeature.iconToken,
            symbol: pointFeature.symbol,
            colorHex: pointFeature.colorHex,
            centerX: pointFeature.centerX,
            centerY: pointFeature.centerY,
            size: pointFeature.size
        )
    }

    private func pointLegendElement(iconToken: PointFeatureIconToken?, symbol: PointFeatureSymbol?, colorHex: String?, centerX: Double, centerY: Double, size: Double) -> String {
        let half = size / 2
        let color = colorHex ?? "#111111"
        if let iconToken,
           let iconElement = PointFeatureIconRenderer.svgElement(
               token: iconToken,
               colorHex: color,
               centerX: centerX,
               centerY: centerY,
               size: size
           ) {
            return "  \(iconElement)"
        }
        guard let symbol else { return "" }
        switch symbol {
        case .diamond:
            return """
              <path d="M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY)) L \(fmt(centerX)) \(fmt(centerY + half)) L \(fmt(centerX - half)) \(fmt(centerY)) Z" fill="\(color)" fill-opacity="0.18" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        case .square:
            return """
              <rect x="\(fmt(centerX - half))" y="\(fmt(centerY - half))" width="\(fmt(size))" height="\(fmt(size))" fill="\(color)" fill-opacity="0.18" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        case .triangle:
            return """
              <path d="M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY + half)) L \(fmt(centerX - half)) \(fmt(centerY + half)) Z" fill="\(color)" fill-opacity="0.18" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        case .circle:
            return """
              <circle cx="\(fmt(centerX))" cy="\(fmt(centerY))" r="\(fmt(half))" fill="\(color)" fill-opacity="0.18" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        case .cross:
            return """
              <path d="M \(fmt(centerX - half)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY + half)) M \(fmt(centerX + half)) \(fmt(centerY - half)) L \(fmt(centerX - half)) \(fmt(centerY + half))" fill="none" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        case .plus:
            return """
              <path d="M \(fmt(centerX - half)) \(fmt(centerY)) L \(fmt(centerX + half)) \(fmt(centerY)) M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX)) \(fmt(centerY + half))" fill="none" stroke="\(color)" stroke-opacity="0.95" stroke-width="1.1"/>
            """
        }
    }

    private func patternDefinition(for symbol: SymbolPattern) -> String {
        let id = "pattern-\(symbol.rawValue)"
        switch symbol {
        case .sandstone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"10\" height=\"10\"><path d=\"M0,10 L10,0\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .mudstone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"10\" height=\"8\"><path d=\"M0,4 L10,4\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .shale:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"12\" height=\"8\"><path d=\"M0,4 L12,4 M0,8 L8,0\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .limestone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"12\" height=\"12\"><path d=\"M0,6 L12,6 M0,12 L12,12 M0,0 L0,6 M6,6 L6,12\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.7\"/></pattern>"
        case .dolostone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"12\" height=\"12\"><path d=\"M0,6 L12,6 M0,12 L12,12 M0,0 L0,6 M6,6 L6,12 M0,12 L12,0\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.7\"/></pattern>"
        case .conglomerate:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"14\" height=\"14\"><circle cx=\"4\" cy=\"4\" r=\"2.8\" fill=\"none\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/><circle cx=\"11\" cy=\"10\" r=\"2.6\" fill=\"none\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .siltstone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"10\" height=\"10\"><circle cx=\"5\" cy=\"5\" r=\"1.2\" fill=\"#222\" fill-opacity=\"0.4\"/></pattern>"
        case .claystone:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"8\" height=\"4\"><path d=\"M0,2 L8,2\" stroke=\"#222\" stroke-opacity=\"0.5\" stroke-width=\"0.8\"/></pattern>"
        case .marl:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"11\" height=\"11\"><path d=\"M0,6 L11,6\" stroke=\"#222\" stroke-opacity=\"0.4\" stroke-width=\"0.8\"/><circle cx=\"5.5\" cy=\"2.2\" r=\"1.1\" fill=\"#222\" fill-opacity=\"0.35\"/></pattern>"
        case .chert:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"10\" height=\"10\"><path d=\"M0,5 L10,5 M5,0 L5,10\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .coal:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"8\" height=\"8\"><path d=\"M0,4 L8,4 M4,0 L4,8 M0,0 L8,8 M0,8 L8,0\" stroke=\"#111\" stroke-opacity=\"0.45\" stroke-width=\"0.7\"/></pattern>"
        case .evaporite:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"12\" height=\"12\"><path d=\"M0,12 L12,0 M0,0 L12,12\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        case .fallback:
            return "<pattern id=\"\(id)\" patternUnits=\"userSpaceOnUse\" width=\"12\" height=\"12\"><path d=\"M0,12 L12,0\" stroke=\"#222\" stroke-opacity=\"0.45\" stroke-width=\"0.8\"/></pattern>"
        }
    }

    private func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func fmt(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.3f", value)
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

    private func grainScaleLabelPlacements(
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

    private func grainLabelPriority(_ label: String) -> Int {
        switch label {
        case SceneLayout.grainScaleFineLabel(), SceneLayout.grainScaleCoarseLabel():
            return 3
        case SceneLayout.grainScaleSiltLabel():
            return 2
        case SceneLayout.grainScaleSandLabel():
            return 1
        default:
            return 1
        }
    }

    private func measuredTextWidth(_ text: String, fontSize: Double, bold: Bool) -> Double {
        let font: NSFont = bold
            ? .boldSystemFont(ofSize: CGFloat(fontSize))
            : .systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return NSString(string: text).size(withAttributes: attributes).width
    }

}
