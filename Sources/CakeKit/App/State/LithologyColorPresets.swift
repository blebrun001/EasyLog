import Foundation

/// A named mapping of USGS lithology codes to custom hex colors.
public struct LithologyColorProfile: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var mappings: [Int: String]

    public init(id: UUID = UUID(), name: String, mappings: [Int: String] = [:]) {
        self.id = id
        self.name = Self.normalizedName(name)
        self.mappings = Self.normalizedMappings(mappings)
    }

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

    public static func normalizedName(_ raw: String, fallback: String = "New Profile") -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    public static func normalizedMappings(_ raw: [Int: String]) -> [Int: String] {
        var normalized: [Int: String] = [:]
        normalized.reserveCapacity(raw.count)

        for (code, color) in raw {
            guard code > 0, let hex = normalizedHex(color) else { continue }
            normalized[code] = hex
        }

        return normalized
    }
}

/// Persisted app-level state for lithology color presets.
public struct LithologyColorPresetStore: Codable, Hashable {
    public var profiles: [LithologyColorProfile]
    public var activeProfileID: UUID

    public init(profiles: [LithologyColorProfile], activeProfileID: UUID?) {
        let sanitizedProfiles = profiles.map {
            LithologyColorProfile(id: $0.id, name: $0.name, mappings: $0.mappings)
        }

        if sanitizedProfiles.isEmpty {
            let fallback = Self.defaultProfile
            self.profiles = [fallback]
            self.activeProfileID = fallback.id
            return
        }

        self.profiles = sanitizedProfiles
        if let activeProfileID,
           sanitizedProfiles.contains(where: { $0.id == activeProfileID }) {
            self.activeProfileID = activeProfileID
        } else {
            self.activeProfileID = sanitizedProfiles[0].id
        }
    }

    public init() {
        self.init(profiles: [Self.defaultProfile], activeProfileID: Self.defaultProfile.id)
    }

    public var activeProfile: LithologyColorProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    public static var defaultProfile: LithologyColorProfile {
        LithologyColorProfile(name: "Default")
    }
}

public protocol LithologyColorPresetPersisting {
    func load() -> LithologyColorPresetStore
    func save(_ store: LithologyColorPresetStore)
}

/// UserDefaults-backed persistence for app-level lithology color presets.
public struct UserDefaultsLithologyColorPresetStore: LithologyColorPresetPersisting {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        key: String = "cake.editor.lithologyColorPresetStore"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> LithologyColorPresetStore {
        guard let data = defaults.data(forKey: key) else {
            return LithologyColorPresetStore()
        }

        do {
            let decoded = try decoder.decode(LithologyColorPresetStore.self, from: data)
            return LithologyColorPresetStore(
                profiles: decoded.profiles,
                activeProfileID: decoded.activeProfileID
            )
        } catch {
            return LithologyColorPresetStore()
        }
    }

    public func save(_ store: LithologyColorPresetStore) {
        let normalized = LithologyColorPresetStore(
            profiles: store.profiles,
            activeProfileID: store.activeProfileID
        )

        guard let data = try? encoder.encode(normalized) else { return }
        defaults.set(data, forKey: key)
    }
}
