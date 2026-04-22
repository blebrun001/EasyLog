import Foundation
import Testing
@testable import EasyLogKit

@Test
func csvLogExporterWritesHeaderAndOneRowPerUnit() throws {
    let project = Project(
        metadata: ProjectMetadata(title: "CSV Project"),
        units: [
            StratigraphicUnit(name: "US-1", thickness: 1.25, usgsLithologyCode: 607, grainSize: .sand),
            StratigraphicUnit(name: "US-2", thickness: 2.5, usgsLithologyCode: 627, grainSize: .granule)
        ]
    )
    let url = makeTempFileURL(prefix: "csv-export", ext: "csv")

    try CSVLogExporter().export(project: project, to: url)

    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

    #expect(lines.count == 3)
    #expect(lines[0] == "log_title;us_index;us_name;thickness_m;lithology_code;lithology_label;grain_size;point_features_count;point_features_labels")
    #expect(lines[1].contains("CSV Project;1;US-1;1.25;607;Massive sand or sandstone;sand;0;"))
    #expect(lines[2].contains("CSV Project;2;US-2;2.5;627;Limestone;granule;0;"))
}

@Test
func csvLogExporterEscapesSemicolonsQuotesAndNewlines() throws {
    let project = Project(
        metadata: ProjectMetadata(title: "Title;\"A\""),
        units: [
            StratigraphicUnit(
                name: "US;\"1\"\nA",
                thickness: 1,
                usgsLithologyCode: 607,
                pointFeatures: [
                    UnitPointFeature(type: .paleoRoots, density: 0.3),
                    UnitPointFeature(type: .paleoMacroFossils, density: 0.8)
                ]
            )
        ]
    )
    let url = makeTempFileURL(prefix: "csv-escape", ext: "csv")

    try CSVLogExporter().export(project: project, to: url)

    let contents = try String(contentsOf: url, encoding: .utf8)
    #expect(contents.contains("\"Title;\"\"A\"\"\""))
    #expect(contents.contains("\"US;\"\"1\"\"\nA\""))
    #expect(contents.contains("2"))
    #expect(contents.contains("Roots (Modern or Fossil) | Macrofossils"))
}
