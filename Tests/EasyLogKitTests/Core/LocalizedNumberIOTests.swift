import Foundation
import Testing
@testable import EasyLogKit

@Test
func localizedNumberIOAlwaysFormatsWithEnglishDecimalSeparator() {
    let io = LocalizedNumberIO()
    #expect(io.locale.identifier == "en_US_POSIX")
    #expect(io.format(12.5) == "12.5")
}

@Test
func localizedNumberIOParsesDotAndCommaSeparators() {
    let io = LocalizedNumberIO()
    #expect(io.parse("12,5") == 12.5)
    #expect(io.parse("12.5") == 12.5)
    #expect(io.parse("  7,25  ") == 7.25)
}
