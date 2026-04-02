import Testing
@testable import CakeKit

@Test
func unknownLithologyFallsBackToDefault() {
    let style = SymbologyLibrary.style(forLithology: "mystery-rock")
    #expect(style.symbol == .fallback)
}

@Test
func everySupportedLithologyHasUSGSCode() {
    let missing = SymbologyLibrary.supportedLithologies.filter {
        SymbologyLibrary.usgsSymbolCode(forLithology: $0) == nil
    }
    #expect(missing.isEmpty)
}
