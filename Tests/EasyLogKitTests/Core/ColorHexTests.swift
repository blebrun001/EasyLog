import AppKit
import Foundation
import Testing
@testable import EasyLogKit

@Test
func colorHexParsesNormalizesAndFallsBack() {
    let fallback = NSColor.magenta.cgColor

    let parsed = ColorHex.cgColor(from: " 12ab34 ", fallback: fallback)
    let fallbackColor = ColorHex.cgColor(from: "bad-value", fallback: fallback)

    #expect(parsed != fallback)
    #expect(fallbackColor == fallback)
}

@Test
func colorHexRoundTripProducesExpectedHex() {
    let color = NSColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    let hex = ColorHex.hex(from: color)

    #expect(hex == "#336699")
    #expect(ColorHex.nsColor(from: "#336699") != nil)
}
