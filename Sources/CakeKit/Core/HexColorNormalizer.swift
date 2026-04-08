import Foundation

/// Shared normalization for user-provided 6-digit RGB hex colors.
public enum HexColorNormalizer {
    public static func normalizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEF")
        guard value.count == 6, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }
        return "#\(value)"
    }
}
