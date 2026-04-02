import AppKit

/// Hex color parsing helpers shared by renderers and exporters.
public enum ColorHex {
    public static func cgColor(from hex: String?, fallback: CGColor) -> CGColor {
        guard let hex, let color = nsColor(from: hex) else { return fallback }
        return color.cgColor
    }

    public static func nsColor(from hex: String) -> NSColor? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = Int(value, radix: 16) else {
            return nil
        }

        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
