import Foundation
import Testing
@testable import EasyLogKit

@Test
func userDefaultsPresetStoreReturnsDefaultProfileWhenNoData() {
    let suiteName = "easylog-preset-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsLithologyColorPresetStore(defaults: defaults, key: "preset-store")
    let loaded = store.load()

    #expect(loaded.profiles.count == 1)
    #expect(loaded.profiles[0].name == "Default")
    #expect(loaded.activeProfileID == loaded.profiles[0].id)
}

@Test
func userDefaultsPresetStoreRoundTripPreservesProfilesAndMappings() {
    let suiteName = "easylog-preset-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    let store = UserDefaultsLithologyColorPresetStore(defaults: defaults, key: "preset-store")
    let profileA = LithologyColorProfile(name: "A", mappings: [627: "#aa11cc"])
    let profileB = LithologyColorProfile(name: "B", mappings: [607: "#001122"])
    let payload = LithologyColorPresetStore(profiles: [profileA, profileB], activeProfileID: profileB.id)

    store.save(payload)
    let loaded = store.load()

    #expect(loaded.profiles.count == 2)
    #expect(loaded.activeProfileID == profileB.id)
    #expect(loaded.profiles.first(where: { $0.id == profileA.id })?.mappings[627] == "#AA11CC")
    #expect(loaded.profiles.first(where: { $0.id == profileB.id })?.mappings[607] == "#001122")
}

@Test
func userDefaultsPresetStoreFallsBackToDefaultWhenDataIsInvalid() {
    let suiteName = "easylog-preset-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }

    defaults.set(Data("invalid-json".utf8), forKey: "preset-store")
    let store = UserDefaultsLithologyColorPresetStore(defaults: defaults, key: "preset-store")
    let loaded = store.load()

    #expect(loaded.profiles.count == 1)
    #expect(loaded.profiles[0].name == "Default")
}

