import Foundation

public struct SVGExporter: SVGExporting {
    public init() {}

    public func export(scene: RenderScene, to url: URL, canvas: CGSizeDTO) throws {
        let usgsPatternByCode = buildUSGSPatternDefinitions(scene: scene)
        var svg = ""
        svg += """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="\(fmt(canvas.width))" height="\(fmt(canvas.height))" viewBox="0 0 \(fmt(canvas.width)) \(fmt(canvas.height))">
          <title>\(xmlEscape(scene.title))</title>
          <defs>
        \(patternDefinitions(scene: scene, usgsPatternByCode: usgsPatternByCode))
          </defs>
          <rect width="100%" height="100%" fill="#ffffff"/>
        """

        svg += "\n  <g id=\"units\">"
        for unit in scene.units {
            let style = SymbologyLibrary.style(forLithology: unit.lithology)
            let fill = style.fillHex
            svg += """

            <g id="unit-\(unit.id.uuidString)">
              <rect x="\(fmt(unit.rect.x))" y="\(fmt(unit.rect.y))" width="\(fmt(unit.rect.width))" height="\(fmt(unit.rect.height))" fill="\(fill)" class="unit-fill"/>
              <rect x="\(fmt(unit.rect.x))" y="\(fmt(unit.rect.y))" width="\(fmt(unit.rect.width))" height="\(fmt(unit.rect.height))" fill="url(#\(patternID(symbol: unit.symbol, usgsSymbolCode: unit.usgsSymbolCode, availableUSGSCodes: usgsPatternByCode)))" class="unit-pattern"/>
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
            let textY = unit.rect.y + unit.rect.height / 2 + 4
            let escaped = xmlEscape("\(unit.name) (\(fmt(unit.thickness)) m)")
            svg += """

            <text x="\(fmt(unit.rect.x + unit.rect.width + 14))" y="\(fmt(textY))">\(escaped)</text>
            """
        }
        svg += "\n  </g>"

        let axisX = scene.logColumnRect.x - 28
        svg += """

          <g id="scale" stroke="#111111" fill="none" stroke-width="1">
            <line x1="\(fmt(axisX))" y1="\(fmt(scene.logColumnRect.y))" x2="\(fmt(axisX))" y2="\(fmt(scene.logColumnRect.y + scene.logColumnRect.height))"/>
        """
        for tick in scene.ticks {
            svg += """

                <line x1="\(fmt(axisX - 6))" y1="\(fmt(tick.y))" x2="\(fmt(axisX + 6))" y2="\(fmt(tick.y))"/>
            """
        }
        svg += "\n  </g>"

        svg += "\n  <g id=\"scale-labels\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"\(fmt(scene.baseFontSize - 1))\" fill=\"#111111\">"
        for tick in scene.ticks {
            svg += """

            <text x="\(fmt(axisX - 62))" y="\(fmt(tick.y + 4))">\(formattedScaleDepth(tick.depth, unit: scene.depthScaleUnit))</text>
            """
        }
        svg += """

            <text x="\(fmt(axisX - 74))" y="\(fmt(scene.logColumnRect.y - 16))">Depth (\(scene.depthScaleUnit.symbol))</text>
          </g>
        """

        let legendX = scene.logColumnRect.x + scene.logColumnRect.width + 170
        var legendY = scene.logColumnRect.y + 10
        svg += """

          <g id="legend">
            <text x="\(fmt(legendX))" y="\(fmt(legendY - 10))" font-family="Helvetica, Arial, sans-serif" font-size="\(fmt(scene.baseFontSize + 1))" font-weight="700">Legend</text>
        """
        for item in scene.legend {
            svg += """

              <rect x="\(fmt(legendX))" y="\(fmt(legendY))" width="28" height="18" fill="#ffffff"/>
            """
            if let pointSymbol = item.pointSymbol {
                svg += "\n\(pointLegendElement(symbol: pointSymbol, centerX: legendX + 14, centerY: legendY + 9, size: 8))"
            } else {
                svg += "\n  <rect x=\"\(fmt(legendX))\" y=\"\(fmt(legendY))\" width=\"28\" height=\"18\" fill=\"url(#\(patternID(symbol: item.symbol, usgsSymbolCode: item.usgsSymbolCode, availableUSGSCodes: usgsPatternByCode)))\"/>"
            }
            svg += """
              <rect x="\(fmt(legendX))" y="\(fmt(legendY))" width="28" height="18" fill="none" stroke="#111111" stroke-width="1"/>
              <text x="\(fmt(legendX + 36))" y="\(fmt(legendY + 13))" font-family="Helvetica, Arial, sans-serif" font-size="\(fmt(scene.baseFontSize - 1))">\(xmlEscape(item.label))</text>
            """
            legendY += 26
        }
        svg += "\n  </g>\n</svg>\n"

        try svg.write(to: url, atomically: true, encoding: .utf8)
    }

    private func patternDefinitions(scene: RenderScene, usgsPatternByCode: [Int: String]) -> String {
        var definitions: [String] = []
        definitions.append(contentsOf: usgsPatternByCode.values.sorted())

        var fallbackSymbols = Set<SymbolPattern>()
        for unit in scene.units where unit.usgsSymbolCode == nil || usgsPatternByCode[unit.usgsSymbolCode ?? -1] == nil {
            fallbackSymbols.insert(unit.symbol)
        }
        for item in scene.legend where item.pointSymbol == nil && (item.usgsSymbolCode == nil || usgsPatternByCode[item.usgsSymbolCode ?? -1] == nil) {
            fallbackSymbols.insert(item.symbol)
        }
        definitions.append(contentsOf: fallbackSymbols.sorted(by: { $0.rawValue < $1.rawValue }).map { patternDefinition(for: $0) })
        return definitions.joined(separator: "\n")
    }

    private func buildUSGSPatternDefinitions(scene: RenderScene) -> [Int: String] {
        var codes = Set<Int>()
        scene.units.compactMap(\.usgsSymbolCode).forEach { codes.insert($0) }
        scene.legend.compactMap(\.usgsSymbolCode).forEach { codes.insert($0) }

        var map: [Int: String] = [:]
        for code in codes.sorted() {
            guard let tile = USGSEPSSymbolRenderer.pngTileData(for: code, maxDimension: 2048) else { continue }
            guard let tileSize = USGSEPSSymbolRenderer.tileSizePoints(for: code, symbolScale: scene.symbolScale) else { continue }
            let id = "pattern-usgs-\(code)"
            let base64 = tile.data.base64EncodedString()
            let tileWidth = max(tileSize.width, 1)
            let tileHeight = max(tileSize.height, 1)
            map[code] = """
            <pattern id="\(id)" patternUnits="userSpaceOnUse" width="\(fmt(tileWidth))" height="\(fmt(tileHeight))">
              <image x="0" y="0" width="\(fmt(tileWidth))" height="\(fmt(tileHeight))" preserveAspectRatio="none" href="data:image/png;base64,\(base64)" xlink:href="data:image/png;base64,\(base64)"/>
            </pattern>
            """
        }
        return map
    }

    private func patternID(symbol: SymbolPattern, usgsSymbolCode: Int?, availableUSGSCodes: [Int: String]) -> String {
        if let usgsSymbolCode, availableUSGSCodes[usgsSymbolCode] != nil {
            return "pattern-usgs-\(usgsSymbolCode)"
        }
        return "pattern-\(symbol.rawValue)"
    }

    private func pointFeatureElement(_ pointFeature: RenderedPointFeature) -> String {
        pointLegendElement(
            symbol: pointFeature.symbol,
            centerX: pointFeature.centerX,
            centerY: pointFeature.centerY,
            size: pointFeature.size
        )
    }

    private func pointLegendElement(symbol: PointFeatureSymbol, centerX: Double, centerY: Double, size: Double) -> String {
        let half = size / 2
        switch symbol {
        case .diamond:
            return """
              <path d="M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY)) L \(fmt(centerX)) \(fmt(centerY + half)) L \(fmt(centerX - half)) \(fmt(centerY)) Z" fill="#ffffff" fill-opacity="0.95" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
            """
        case .square:
            return """
              <rect x="\(fmt(centerX - half))" y="\(fmt(centerY - half))" width="\(fmt(size))" height="\(fmt(size))" fill="#ffffff" fill-opacity="0.95" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
            """
        case .triangle:
            return """
              <path d="M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY + half)) L \(fmt(centerX - half)) \(fmt(centerY + half)) Z" fill="#ffffff" fill-opacity="0.95" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
            """
        case .circle:
            return """
              <circle cx="\(fmt(centerX))" cy="\(fmt(centerY))" r="\(fmt(half))" fill="#ffffff" fill-opacity="0.95" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
            """
        case .cross:
            return """
              <path d="M \(fmt(centerX - half)) \(fmt(centerY - half)) L \(fmt(centerX + half)) \(fmt(centerY + half)) M \(fmt(centerX + half)) \(fmt(centerY - half)) L \(fmt(centerX - half)) \(fmt(centerY + half))" fill="none" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
            """
        case .plus:
            return """
              <path d="M \(fmt(centerX - half)) \(fmt(centerY)) L \(fmt(centerX + half)) \(fmt(centerY)) M \(fmt(centerX)) \(fmt(centerY - half)) L \(fmt(centerX)) \(fmt(centerY + half))" fill="none" stroke="#111111" stroke-opacity="0.88" stroke-width="1.1"/>
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

    private func formattedScaleDepth(_ depthInMeters: Double, unit: DepthScaleUnit) -> String {
        let scaled = depthInMeters * unit.multiplierFromMeters
        switch unit {
        case .meter:
            return fmt(scaled)
        case .centimeter, .millimeter:
            return String(Int(scaled.rounded()))
        }
    }
}
