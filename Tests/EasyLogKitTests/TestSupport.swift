import Foundation
@testable import EasyLogKit

func usgsCode(_ lithologyLabel: String) -> Int {
    SymbologyLibrary.usgsSymbolCode(forLithology: lithologyLabel) ?? 607
}

func isolatedDefaults(prefix: String = "easylog-tests") -> UserDefaults {
    UserDefaults(suiteName: "\(prefix)-\(UUID().uuidString)")!
}
