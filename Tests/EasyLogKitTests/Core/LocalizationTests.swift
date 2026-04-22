import Foundation
import Testing
@testable import EasyLogKit

@Test
func localizableCatalogHasNoEmptyOrPartialLocalizations() throws {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let catalogURL = repoRoot
        .appendingPathComponent("Sources")
        .appendingPathComponent("EasyLogKit")
        .appendingPathComponent("Resources")
        .appendingPathComponent("Localizable.xcstrings")

    let data = try Data(contentsOf: catalogURL)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let strings = object?["strings"] as? [String: Any] ?? [:]
    let expectedLanguages: Set<String> = ["en", "fr", "es", "ca", "el"]

    for (key, rawEntry) in strings {
        let entry = rawEntry as? [String: Any] ?? [:]
        let localizations = entry["localizations"] as? [String: Any]
        #expect(localizations != nil, "Missing localizations for key \(key)")
        let presentLanguages = localizations.map { Set($0.keys) } ?? []
        #expect(presentLanguages == expectedLanguages, "Unexpected languages for key \(key)")
    }

    for requiredKey in [
        "status.ready",
        "panel.openProject.title",
        "render.legend.title",
        "render.axis.depth",
        "render.axis.altitude",
        "render.grainScale.title",
        "render.unit.untitled",
        "Export All CSV…"
    ] {
        #expect(strings[requiredKey] != nil, "Missing required key \(requiredKey)")
    }
}

@Test
func localizationServiceResolvesConfiguredLanguage() {
    let suite = "easylog-l10n-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
    }
    defaults.set("fr", forKey: EasyLogPreferencesKey.appLanguage)

    let localizer = LocalizationService(defaults: defaults, bundle: EasyLogKitBundle.resources)
    #expect(localizer.locale.identifier.hasPrefix("fr"))
    #expect(localizer.text("render.legend.title") == "Légende")
}

@Test
func sceneLayoutUsesInjectedLocalizerForAxisAndFallbackLabels() {
    let suite = "easylog-layout-l10n-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer {
        defaults.removePersistentDomain(forName: suite)
    }
    defaults.set("es", forKey: EasyLogPreferencesKey.appLanguage)
    let localizer = LocalizationService(defaults: defaults, bundle: EasyLogKitBundle.resources)

    #expect(SceneLayout.scaleAxisTitle(unit: .meter, zeroLevelAltitudeInMeters: nil, localizer: localizer) == "Profundidad (m)")
    #expect(SceneLayout.scaleAxisTitle(unit: .meter, zeroLevelAltitudeInMeters: 123, localizer: localizer) == "Altitud (m)")
    let unnamedUnit = RenderedUnit(
        id: UUID(),
        name: " ",
        thickness: 1.0,
        lithology: "Test",
        symbol: .sandstone,
        fillHex: "#FFFFFF",
        rect: RectD(x: 0, y: 0, width: 10, height: 10)
    )
    #expect(SceneLayout.unitPrimaryLabel(unnamedUnit, localizer: localizer) == "Unidad sin título")
}
