import Testing
@testable import EasyLogKit

@Test
func normalizedHexAcceptsCanonicalAndTrimmedValues() {
    #expect(HexColorNormalizer.normalizedHex("#aBc123") == "#ABC123")
    #expect(HexColorNormalizer.normalizedHex("  abc123  ") == "#ABC123")
    #expect(HexColorNormalizer.normalizedHex(nil) == nil)
}

@Test
func normalizedHexRejectsInvalidValues() {
    #expect(HexColorNormalizer.normalizedHex("#12345") == nil)
    #expect(HexColorNormalizer.normalizedHex("#12GG45") == nil)
    #expect(HexColorNormalizer.normalizedHex("") == nil)
}

@Test
func colorNormalizersStayAlignedAcrossCallers() {
    let raw = "#12ab34"
    let expected = "#12AB34"
    #expect(HexColorNormalizer.normalizedHex(raw) == expected)
    #expect(ColorHex.normalizedHex(raw) == expected)
    #expect(LithologyColorProfile.normalizedHex(raw) == expected)
}
