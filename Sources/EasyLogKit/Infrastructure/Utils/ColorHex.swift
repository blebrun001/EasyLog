import AppKit

/// Hex color parsing helpers shared by renderers and exporters.
public enum ColorHex {
    public static func cgColor(from hex: String?, fallback: CGColor) -> CGColor {
        guard let hex, let color = nsColor(from: hex) else { return fallback }
        return color.cgColor
    }

    public static func nsColor(from hex: String) -> NSColor? {
        guard let normalized = normalizedHex(hex) else {
            return nil
        }
        let value = String(normalized.dropFirst())
        guard let rgb = Int(value, radix: 16) else { return nil }

        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0
        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    public static func normalizedHex(_ raw: String?) -> String? {
        HexColorNormalizer.normalizedHex(raw)
    }

    public static func hex(from color: NSColor) -> String? {
        guard let converted = color.usingColorSpace(.deviceRGB) else { return nil }
        let red = Int((converted.redComponent * 255).rounded())
        let green = Int((converted.greenComponent * 255).rounded())
        let blue = Int((converted.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
