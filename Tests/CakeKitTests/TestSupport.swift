import Foundation
@testable import CakeKit

func usgsCode(_ lithologyLabel: String) -> Int {
    SymbologyLibrary.usgsSymbolCode(forLithology: lithologyLabel) ?? 607
}

func isolatedDefaults(prefix: String = "cake-tests") -> UserDefaults {
    UserDefaults(suiteName: "\(prefix)-\(UUID().uuidString)")!
}
