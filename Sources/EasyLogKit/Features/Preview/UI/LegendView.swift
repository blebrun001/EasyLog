import AppKit
import SwiftUI

/// Compact legend list used in side panels and export previews.
public struct LegendView: View {
    private let legend: [LegendItem]

    public init(legend: [LegendItem]) {
        self.legend = legend
    }

    public var body: some View {
        ProPanelSection("Legend", subtitle: "Symbols visible in current log") {
            if legend.isEmpty {
                ProEmptyState(
                    title: "No symbols in current log",
                    message: "Add units or features to populate the legend.",
                    systemImage: "list.bullet.rectangle"
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { _, item in
                        HStack {
                            SymbolSwatch(
                                symbol: item.symbol,
                                pointIconToken: item.pointIconToken,
                                pointSymbol: item.pointSymbol,
                                pointColorHex: item.pointColorHex,
                                fillHex: item.fillHex
                            )
                            Text(item.label)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

private struct SymbolSwatch: View {
    let symbol: SymbolPattern
    let pointIconToken: PointFeatureIconToken?
    let pointSymbol: PointFeatureSymbol?
    let pointColorHex: String?
    let fillHex: String?

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                let rect = CGRect(origin: .zero, size: size)
                let fallback = NSColor.white.cgColor
                let fill = (pointSymbol == nil && pointIconToken == nil)
                    ? ColorHex.cgColor(from: fillHex, fallback: fallback)
                    : fallback
                cgContext.setFillColor(fill)
                cgContext.fill(rect)
                if pointIconToken != nil || pointSymbol != nil {
                    let strokeColor = ColorHex.cgColor(from: pointColorHex, fallback: NSColor.black.cgColor)
                    let fillColor = ColorHex.cgColor(from: pointColorHex, fallback: NSColor.white.cgColor)
                    SceneCGRenderer.drawPointIcon(
                        pointIconToken,
                        fallbackSymbol: pointSymbol,
                        center: CGPoint(x: rect.midX, y: rect.midY),
                        size: 8,
                        strokeColor: strokeColor,
                        fillColor: fillColor,
                        context: cgContext
                    )
                } else {
                    SceneCGRenderer.drawSymbolPattern(symbol, in: rect, context: cgContext)
                }
                cgContext.setStrokeColor(NSColor.black.cgColor)
                cgContext.stroke(rect)
            }
        }
        .frame(width: 28, height: 18)
    }
}
