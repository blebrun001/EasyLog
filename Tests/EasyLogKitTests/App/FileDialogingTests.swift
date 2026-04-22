import Foundation
import Testing
@testable import EasyLogKit

#if canImport(AppKit)
@Test
@MainActor
func exportFormatMappingTreatsJPEGExtensionAsJPG() {
    let url = URL(fileURLWithPath: "/tmp/easylog-export.jpeg")
    #expect(AppKitFileDialogService.exportFormat(for: url) == .jpg)
}

@Test
@MainActor
func exportFormatMappingTreatsCSVExtensionAsCSV() {
    let url = URL(fileURLWithPath: "/tmp/easylog-export.csv")
    #expect(AppKitFileDialogService.exportFormat(for: url) == .csv)
}
#endif
