import Testing
@testable import CakeKit

@Test
func validationReportIncludesStructuredEntries() {
    var project = Project(
        settings: ProjectSettings(),
        units: [
            StratigraphicUnit(name: "", thickness: 0, usgsLithologyCode: -1)
        ]
    )
    project.settings.verticalScale = 0
    project.settings.baseFontSize = 0

    let report = ProjectValidator.validateReport(project)

    #expect(!report.entries.isEmpty)
    #expect(report.hasErrors)
    #expect(report.entries.contains { $0.code == "UNIT_THICKNESS_NON_POSITIVE" })
    #expect(report.entries.contains { $0.scope == .settings })
}

@Test
func projectSettingsClampInvalidValues() {
    let settings = ProjectSettings(
        verticalScale: -4,
        baseFontSize: 0,
        symbolScale: 0,
        pointFeatureIconSize: 999
    )

    #expect(settings.verticalScale >= 0.1)
    #expect(settings.baseFontSize >= 1)
    #expect(settings.symbolScale >= 0.05)
    #expect(settings.pointFeatureIconSize == ProjectSettings.pointFeatureIconSizeRange.upperBound)
}
