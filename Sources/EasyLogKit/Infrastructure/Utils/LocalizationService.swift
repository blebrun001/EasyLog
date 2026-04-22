import Foundation

/// Shared localization helper that resolves strings using the app language preference.
public struct LocalizationService: @unchecked Sendable {
    public let defaults: UserDefaults
    public let bundle: Bundle
    public let fallback: [String: String]

    public init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = EasyLogKitBundle.resources,
        fallback: [String: String] = [:]
    ) {
        self.defaults = defaults
        self.bundle = bundle
        self.fallback = fallback
    }

    public var locale: Locale {
        let code = defaults.string(forKey: EasyLogPreferencesKey.appLanguage) ?? "en"
        return Locale(identifier: code)
    }

    public func text(_ key: String) -> String {
        let value = String(localized: String.LocalizationValue(key), bundle: bundle, locale: locale)
        if value != key {
            return value
        }
        if let catalogValue = catalogLookup(for: key, locale: locale) {
            return catalogValue
        }
        return fallback[key] ?? key
    }

    public func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: args)
    }

    public func format(_ key: String, _ args: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: args)
    }

    private func catalogLookup(for key: String, locale: Locale) -> String? {
        guard let url = bundle.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = raw["strings"] as? [String: Any],
              let entry = strings[key] as? [String: Any],
              let localizations = entry["localizations"] as? [String: Any] else {
            return nil
        }

        let primaryCode = locale.language.languageCode?.identifier
            ?? locale.identifier.split(separator: "_").first.map(String.init)
            ?? "en"
        let fallbackCodes = [primaryCode, "en"]

        for code in fallbackCodes {
            guard let localized = localizations[code] as? [String: Any],
                  let stringUnit = localized["stringUnit"] as? [String: Any],
                  let value = stringUnit["value"] as? String else {
                continue
            }
            return value
        }

        return nil
    }
}
