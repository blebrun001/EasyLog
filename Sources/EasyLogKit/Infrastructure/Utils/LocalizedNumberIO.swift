import Foundation

/// Number formatter/parser fixed to English output while accepting dot/comma inputs.
public struct LocalizedNumberIO: @unchecked Sendable {
    public init(defaults _: UserDefaults = .standard) {}

    public var locale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    public func format(
        _ value: Double,
        minFractionDigits: Int = 0,
        maxFractionDigits: Int = 3
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    public func parse(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        if let value = formatter.number(from: trimmed)?.doubleValue {
            return value
        }

        // Accept both decimal separators for resilient input.
        if let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) {
            return value
        }
        return nil
    }
}
