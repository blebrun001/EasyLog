import AppKit
import SwiftUI

/// Compact legend list used in side panels and export previews.
public struct LegendView: View {
    private let legend: [LegendItem]

    public init(legend: [LegendItem]) {
        self.legend = legend
    }

    public var body: some View {
        GroupBox("Legend") {
            if legend.isEmpty {
                Text("No symbols in current log.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { _, item in
                        HStack {
                            SymbolSwatch(symbol: item.symbol, pointSymbol: item.pointSymbol, fillHex: item.fillHex)
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
    let pointSymbol: PointFeatureSymbol?
    let fillHex: String?

    var body: some View {
        Canvas { context, size in
            context.withCGContext { cgContext in
                let rect = CGRect(origin: .zero, size: size)
                let fallback = NSColor.white.cgColor
                let fill = pointSymbol == nil
                    ? ColorHex.cgColor(from: fillHex, fallback: fallback)
                    : fallback
                cgContext.setFillColor(fill)
                cgContext.fill(rect)
                if let pointSymbol {
                    SceneCGRenderer.drawPointSymbol(pointSymbol, center: CGPoint(x: rect.midX, y: rect.midY), size: 8, context: cgContext)
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
