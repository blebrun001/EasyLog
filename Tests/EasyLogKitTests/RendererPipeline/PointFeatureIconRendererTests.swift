import AppKit
import Foundation
import Testing
@testable import EasyLogKit

@Test
func pointFeatureSvgElementExistsForEveryIconToken() {
    for token in PointFeatureIconToken.allCases {
        let svg = PointFeatureIconRenderer.svgElement(
            token: token,
            colorHex: "#112233",
            centerX: 12,
            centerY: 18,
            size: 10
        )
        #expect(svg != nil)
        #expect(svg?.contains("#112233") == true)
    }
}

@Test
func pointFeatureDrawRendersEveryIconTokenWithoutFailure() {
    let context = makeBitmapContext(width: 128, height: 128)!
    let stroke = NSColor.black.cgColor
    let fill = NSColor.white.cgColor

    var x: CGFloat = 10
    var y: CGFloat = 10
    for token in PointFeatureIconToken.allCases {
        let drawn = PointFeatureIconRenderer.draw(
            token: token,
            center: CGPoint(x: x, y: y),
            size: 10,
            strokeColor: stroke,
            fillColor: fill,
            context: context
        )
        #expect(drawn)
        x += 12
        if x > 110 {
            x = 10
            y += 12
        }
    }

    #expect(context.makeImage() != nil)
}

@Test
func sceneCGRasterRendererDrawAndSymbolPatternDoNotCrash() {
    let context = makeBitmapContext(width: 320, height: 220)!
    let scene = makeSimpleScene(canvasWidth: 220, canvasHeight: 160)

    SceneCGRenderer.draw(scene: scene, in: context)
    for symbol in SymbolPattern.allCases {
        SceneCGRenderer.drawSymbolPattern(symbol, in: CGRect(x: 10, y: 10, width: 40, height: 30), context: context, symbolScale: 1)
    }

    #expect(context.makeImage() != nil)
}
