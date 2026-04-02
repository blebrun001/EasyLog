import Testing
@testable import CakeKit

@Test
func unknownLithologyFallsBackToDefault() {
    let style = SymbologyLibrary.style(forLithology: "mystery-rock")
    #expect(style.symbol == .fallback)
}
