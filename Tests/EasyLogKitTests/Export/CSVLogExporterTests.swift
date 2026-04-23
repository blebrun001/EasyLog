import Foundation
import Testing
@testable import EasyLogKit

@Test
func csvLogExporterWritesAnalyticalHeaderAndOneRowPerUnit() throws {
    let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    let updatedAt = Date(timeIntervalSince1970: 1_700_000_600)
    let firstID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let secondID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    let project = Project(
        metadata: ProjectMetadata(
            title: "CSV Project",
            author: "Geo Team",
            createdAt: createdAt,
            updatedAt: updatedAt
        ),
        units: [
            StratigraphicUnit(
                id: firstID,
                name: "US-1",
                thickness: 1.25,
                usgsLithologyCode: 607,
                lithologyColorHex: "#AABBCC",
                grainSize: .sand
            ),
            StratigraphicUnit(
                id: secondID,
                name: "US-2",
                thickness: 2.5,
                usgsLithologyCode: 627,
                grainSize: .granule
            )
        ]
    )
    let url = makeTempFileURL(prefix: "csv-export", ext: "csv")

    try CSVLogExporter().export(project: project, to: url)

    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

    #expect(lines.count == 3)
    #expect(lines[0] == "project_title;project_author;project_created_at_utc;project_updated_at_utc;unit_uuid;unit_index_1_based;unit_name;thickness_m;depth_top_m;depth_base_m;lithology_code;lithology_label;lithology_color_hex;grain_size_code;grain_size_label;point_features_count;point_features_type_codes;point_features_labels;point_features_category_codes;point_features_category_labels;point_features_densities;point_features_color_hexes")

    let firstFields = lines[1].split(separator: ";", omittingEmptySubsequences: false).map(String.init)
    #expect(firstFields[0] == "CSV Project")
    #expect(firstFields[1] == "Geo Team")
    #expect(firstFields[2].hasSuffix("Z"))
    #expect(firstFields[3].hasSuffix("Z"))
    #expect(firstFields[4] == firstID.uuidString.lowercased())
    #expect(firstFields[5] == "1")
    #expect(firstFields[6] == "US-1")
    #expect(firstFields[7] == "1.25")
    #expect(firstFields[8] == "0")
    #expect(firstFields[9] == "1.25")
    #expect(firstFields[10] == "607")
    #expect(firstFields[12] == "#AABBCC")
    #expect(firstFields[13] == "sand")
    #expect(firstFields[14] == "Sand")
    #expect(firstFields[15] == "0")

    let secondFields = lines[2].split(separator: ";", omittingEmptySubsequences: false).map(String.init)
    #expect(secondFields[4] == secondID.uuidString.lowercased())
    #expect(secondFields[7] == "2.5")
    #expect(secondFields[8] == "1.25")
    #expect(secondFields[9] == "3.75")
    #expect(secondFields[10] == "627")
    #expect(secondFields[13] == "granule")
    #expect(secondFields[14] == "Granule")
    #expect(secondFields[15] == "0")
}

@Test
func csvLogExporterSerializesPointFeaturesAsAlignedPipeLists() throws {
    let project = Project(
        units: [
            StratigraphicUnit(
                name: "US-1",
                thickness: 1,
                usgsLithologyCode: 607,
                pointFeatures: [
                    UnitPointFeature(type: .paleoRoots, density: 0.3, colorHex: "#123456"),
                    UnitPointFeature(type: .paleoMacroFossils, density: 0.8)
                ]
            )
        ]
    )
    let url = makeTempFileURL(prefix: "csv-points", ext: "csv")

    try CSVLogExporter().export(project: project, to: url)

    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    let fields = lines[1].split(separator: ";", omittingEmptySubsequences: false).map(String.init)

    #expect(fields[15] == "2")
    #expect(fields[16] == "paleoRoots|paleoMacroFossils")
    #expect(fields[17] == "Roots (Modern or Fossil)|Macrofossils")
    #expect(fields[18] == "biological|biological")
    #expect(fields[19] == "Biological / Paleoenvironmental|Biological / Paleoenvironmental")
    #expect(fields[20] == "0.3|0.8")
    #expect(fields[21] == "#123456|#111111")
}

@Test
func csvLogExporterEscapesSemicolonsQuotesAndNewlines() throws {
    let project = Project(
        metadata: ProjectMetadata(title: "Title;\"A\"", author: "A\nB"),
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
    #expect(contents.contains("\"A\nB\""))
    #expect(contents.contains("\"US;\"\"1\"\"\nA\""))
}

@Test
func csvLogExporterWritesOnlyHeaderForEmptyProject() throws {
    let project = Project(metadata: ProjectMetadata(title: "Empty"), units: [])
    let url = makeTempFileURL(prefix: "csv-empty", ext: "csv")

    try CSVLogExporter().export(project: project, to: url)

    let contents = try String(contentsOf: url, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

    #expect(lines.count == 1)
    #expect(lines[0].contains("project_title;project_author;project_created_at_utc"))
}
