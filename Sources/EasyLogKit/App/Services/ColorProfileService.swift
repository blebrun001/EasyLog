import Foundation

/// Pure helpers around color profile naming and normalized persistence payloads.
public struct ColorProfileService {
    public init() {}

    public func uniqueProfileName(
        base: String,
        existingProfiles: [LithologyColorProfile],
        excludingID: UUID? = nil
    ) -> String {
        let baseName = LithologyColorProfile.normalizedName(base)
        let existing = Set(
            existingProfiles
                .filter { $0.id != excludingID }
                .map { $0.name.lowercased() }
        )

        if !existing.contains(baseName.lowercased()) {
            return baseName
        }

        var suffix = 2
        while true {
            let candidate = "\(baseName) \(suffix)"
            if !existing.contains(candidate.lowercased()) {
                return candidate
            }
            suffix += 1
        }
    }

    public func normalizedStore(
        profiles: [LithologyColorProfile],
        activeProfileID: UUID?
    ) -> LithologyColorPresetStore {
        LithologyColorPresetStore(profiles: profiles, activeProfileID: activeProfileID)
    }
}
