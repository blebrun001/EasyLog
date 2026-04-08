import Foundation

/// Grain-size classes used to infer log column width.
public enum USGSGrainSize: String, Codable, CaseIterable, Identifiable {
    case clay = "clay"
    case silt = "silt"
    case sand = "sand"
    case granule = "granule"
    case pebble = "pebble"
    case cobble = "cobble"
    case boulder = "boulder"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .clay: return "Clay"
        case .silt: return "Silt"
        case .sand: return "Sand"
        case .granule: return "Granule"
        case .pebble: return "Pebble"
        case .cobble: return "Cobble"
        case .boulder: return "Boulder"
        }
    }
}

/// Primitive shapes used for unit point-feature symbols.
public enum PointFeatureSymbol: String, Codable, CaseIterable, Hashable {
    case diamond
    case square
    case triangle
    case circle
    case cross
    case plus
}

/// User-facing qualitative density level for point features.
public enum PointFeatureConcentration: String, Codable, CaseIterable, Identifiable {
    case low
    case high

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .low: return "Low"
        case .high: return "High"
        }
    }
}

/// Display unit used for depth labels on the rendered scale.
public enum DepthScaleUnit: String, Codable, CaseIterable, Identifiable {
    case meter
    case centimeter
    case millimeter

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .meter: return "Meters"
        case .centimeter: return "Centimeters"
        case .millimeter: return "Millimeters"
        }
    }

    public var symbol: String {
        switch self {
        case .meter: return "m"
        case .centimeter: return "cm"
        case .millimeter: return "mm"
        }
    }

    public var multiplierFromMeters: Double {
        switch self {
        case .meter: return 1
        case .centimeter: return 100
        case .millimeter: return 1000
        }
    }
}

/// Grouping taxonomy for unit point features.
public enum PointFeatureCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case biological
    case sedimentary
    case localStructures
    case alteration
    case archaeological
    case hydrological

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .biological: return "Biological / Paleoenvironmental"
        case .sedimentary: return "Sedimentary / Diagenetic"
        case .localStructures: return "Local Structures"
        case .alteration: return "Alteration / Pedogenesis"
        case .archaeological: return "Archaeological"
        case .hydrological: return "Hydrological / Chemical"
        }
    }
}

/// Typed point annotations that can be attached to a stratigraphic unit.
public enum PointFeatureType: String, Codable, CaseIterable, Identifiable {
    case paleoMacroFossils
    case paleoMicrofossils
    case paleoShellFragments
    case paleoPlantRemains
    case paleoRoots
    case paleoBurrowsBioturbation
    case paleoIchnofossils
    case paleoCharcoalOrganicMatter

    case diageneticNodules
    case diageneticConcretions
    case diageneticGeodes
    case diageneticLithicInclusions
    case diageneticDispersedPebbles
    case diageneticReworkedFragments
    case diageneticIntraclasts
    case diageneticStylolites
    case diageneticVeins

    case localLaminations
    case localCrossBedding
    case localIsolatedRipples
    case localDesiccationCracks
    case localLoadStructures
    case localSoftSedimentDeformation

    case pedogenesisOxidationSpots
    case pedogenesisMottling
    case pedogenesisPedologicalHorizons
    case pedogenesisCarbonateAccumulations
    case pedogenesisCrusts

    case archaeologicalArtifacts
    case archaeologicalBoneFragments
    case archaeologicalAnthropicCharcoal
    case archaeologicalPunctualStructures

    case hydroCementedZones
    case hydroLocalizedMineralPrecipitation
    case hydroDissolutionTraces
    case hydroFeMnEnrichedLevels

    public var id: String { rawValue }

    public var category: PointFeatureCategory {
        switch self {
        case .paleoMacroFossils, .paleoMicrofossils, .paleoShellFragments, .paleoPlantRemains, .paleoRoots, .paleoBurrowsBioturbation, .paleoIchnofossils, .paleoCharcoalOrganicMatter:
            return .biological
        case .diageneticNodules, .diageneticConcretions, .diageneticGeodes, .diageneticLithicInclusions, .diageneticDispersedPebbles, .diageneticReworkedFragments, .diageneticIntraclasts, .diageneticStylolites, .diageneticVeins:
            return .sedimentary
        case .localLaminations, .localCrossBedding, .localIsolatedRipples, .localDesiccationCracks, .localLoadStructures, .localSoftSedimentDeformation:
            return .localStructures
        case .pedogenesisOxidationSpots, .pedogenesisMottling, .pedogenesisPedologicalHorizons, .pedogenesisCarbonateAccumulations, .pedogenesisCrusts:
            return .alteration
        case .archaeologicalArtifacts, .archaeologicalBoneFragments, .archaeologicalAnthropicCharcoal, .archaeologicalPunctualStructures:
            return .archaeological
        case .hydroCementedZones, .hydroLocalizedMineralPrecipitation, .hydroDissolutionTraces, .hydroFeMnEnrichedLevels:
            return .hydrological
        }
    }

    public var categoryLabel: String {
        category.label
    }

    public var label: String {
        switch self {
        case .paleoMacroFossils: return "Macrofossils"
        case .paleoMicrofossils: return "Microfossils"
        case .paleoShellFragments: return "Shell Fragments"
        case .paleoPlantRemains: return "Plant Remains"
        case .paleoRoots: return "Roots (Modern or Fossil)"
        case .paleoBurrowsBioturbation: return "Burrows / Bioturbation"
        case .paleoIchnofossils: return "Ichnofossils"
        case .paleoCharcoalOrganicMatter: return "Charcoal / Organic Matter"
        case .diageneticNodules: return "Nodules"
        case .diageneticConcretions: return "Concretions"
        case .diageneticGeodes: return "Geodes"
        case .diageneticLithicInclusions: return "Isolated Lithic Clasts"
        case .diageneticDispersedPebbles: return "Dispersed Pebbles"
        case .diageneticReworkedFragments: return "Reworked Fragments"
        case .diageneticIntraclasts: return "Intraclasts"
        case .diageneticStylolites: return "Stylolites"
        case .diageneticVeins: return "Calcite / Quartz Veins"
        case .localLaminations: return "Local Laminations"
        case .localCrossBedding: return "Localized Cross-Bedding"
        case .localIsolatedRipples: return "Isolated Ripples"
        case .localDesiccationCracks: return "Desiccation Cracks"
        case .localLoadStructures: return "Load Structures"
        case .localSoftSedimentDeformation: return "Soft-Sediment Deformation"
        case .pedogenesisOxidationSpots: return "Oxidation Spots"
        case .pedogenesisMottling: return "Mottling"
        case .pedogenesisPedologicalHorizons: return "Pedological Horizons"
        case .pedogenesisCarbonateAccumulations: return "Carbonate Accumulations"
        case .pedogenesisCrusts: return "Crusts"
        case .archaeologicalArtifacts: return "Artifacts"
        case .archaeologicalBoneFragments: return "Bone Fragments"
        case .archaeologicalAnthropicCharcoal: return "Anthropic Charcoal"
        case .archaeologicalPunctualStructures: return "Point Structures (Hearths, Postholes)"
        case .hydroCementedZones: return "Cemented Zones"
        case .hydroLocalizedMineralPrecipitation: return "Localized Mineral Precipitation"
        case .hydroDissolutionTraces: return "Dissolution Traces"
        case .hydroFeMnEnrichedLevels: return "Fe-Mn Enriched Levels"
        }
    }

    public var symbol: PointFeatureSymbol {
        let symbols = PointFeatureSymbol.allCases
        let index = stableHash(rawValue) % UInt64(symbols.count)
        return symbols[Int(index)]
    }

    public var symbolColorHex: String {
        let palette = [
            "#115D8C",
            "#9A3D1F",
            "#3F6F20",
            "#6C3F99",
            "#8B5A2B",
            "#0A7A73",
            "#A12D6F",
            "#596B7A",
            "#7A4B1D",
            "#2C5D3F"
        ]
        let index = stableHash(rawValue) % UInt64(palette.count)
        return palette[Int(index)]
    }

    private func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

/// Instance of a typed point feature with normalized density.
public struct UnitPointFeature: Identifiable, Codable, Hashable {
    public var id: UUID
    public var type: PointFeatureType
    public var density: Double

    public init(
        id: UUID = UUID(),
        type: PointFeatureType,
        density: Double
    ) {
        self.id = id
        self.type = type
        self.density = Self.clampDensity(density)
    }

    public init(
        id: UUID = UUID(),
        type: PointFeatureType,
        concentration: PointFeatureConcentration
    ) {
        self.id = id
        self.type = type
        self.density = Self.defaultDensity(for: concentration)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case density
        case concentration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try container.decode(PointFeatureType.self, forKey: .type)

        if let rawDensity = try container.decodeIfPresent(Double.self, forKey: .density) {
            density = Self.clampDensity(rawDensity)
        } else if let legacy = try container.decodeIfPresent(PointFeatureConcentration.self, forKey: .concentration) {
            density = Self.defaultDensity(for: legacy)
        } else {
            density = Self.defaultDensity(for: .low)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(Self.clampDensity(density), forKey: .density)
    }

    private static func defaultDensity(for concentration: PointFeatureConcentration) -> Double {
        switch concentration {
        case .low:
            return 0.25
        case .high:
            return 0.75
        }
    }

    private static func clampDensity(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// One layer of the stratigraphic log.
public struct StratigraphicUnit: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var thickness: Double
    public var usgsLithologyCode: Int
    public var lithologyColorHex: String?
    public var grainSize: USGSGrainSize?
    public var pointFeatures: [UnitPointFeature]

    public var lithologyLabel: String {
        SymbologyLibrary.label(forUSGSCode: usgsLithologyCode)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        thickness: Double,
        usgsLithologyCode: Int,
        lithologyColorHex: String? = nil,
        grainSize: USGSGrainSize? = nil,
        pointFeatures: [UnitPointFeature] = []
    ) {
        self.id = id
        self.name = name
        self.thickness = thickness
        self.usgsLithologyCode = usgsLithologyCode
        self.lithologyColorHex = Self.normalizedHexColor(lithologyColorHex)
        self.grainSize = grainSize
        self.pointFeatures = pointFeatures
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case thickness
        case usgsLithologyCode
        case lithologyColorHex
        case grainSize
        case pointFeatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        thickness = try container.decode(Double.self, forKey: .thickness)
        usgsLithologyCode = try container.decodeIfPresent(Int.self, forKey: .usgsLithologyCode) ?? 607
        let rawColorHex = try container.decodeIfPresent(String.self, forKey: .lithologyColorHex)
        lithologyColorHex = Self.normalizedHexColor(rawColorHex)
        grainSize = try container.decodeIfPresent(USGSGrainSize.self, forKey: .grainSize)
        pointFeatures = try container.decodeIfPresent([UnitPointFeature].self, forKey: .pointFeatures) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(usgsLithologyCode, forKey: .usgsLithologyCode)
        try container.encodeIfPresent(Self.normalizedHexColor(lithologyColorHex), forKey: .lithologyColorHex)
        try container.encodeIfPresent(grainSize, forKey: .grainSize)
        try container.encode(pointFeatures, forKey: .pointFeatures)
    }

    private static func normalizedHexColor(_ raw: String?) -> String? {
        HexColorNormalizer.normalizedHex(raw)
    }
}

/// Human/contextual metadata for a project file.
public struct ProjectMetadata: Codable, Hashable {
    public var title: String
    public var author: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        title: String = "Untitled Stratigraphic Log",
        author: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Codable bridge for `CGSize` to keep model pure-Foundation.
public struct CGSizeDTO: Codable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Rendering preferences and export defaults persisted with the project.
public struct ProjectSettings: Codable, Hashable {
    public var verticalScale: Double
    public var baseFontSize: Double
    public var showGrid: Bool
    public var showLegend: Bool
    public var showScale: Bool
    public var showGrainSizeScale: Bool
    public var showLogTitle: Bool
    public var showUSGSCodesInLithologyLabels: Bool
    public var symbolScale: Double
    public var pointFeatureIconSize: Double
    public var depthScaleUnit: DepthScaleUnit
    public var useAbsoluteAltitude: Bool
    public var zeroLevelAltitudeMeters: Double?

    public init(
        verticalScale: Double = 25,
        baseFontSize: Double = 12,
        showGrid: Bool = false,
        showLegend: Bool = true,
        showScale: Bool = true,
        showGrainSizeScale: Bool = true,
        showLogTitle: Bool = true,
        showUSGSCodesInLithologyLabels: Bool = true,
        symbolScale: Double = 1.0,
        pointFeatureIconSize: Double = 8.0,
        depthScaleUnit: DepthScaleUnit = .meter,
        useAbsoluteAltitude: Bool = false,
        zeroLevelAltitudeMeters: Double? = nil
    ) {
        self.verticalScale = verticalScale
        self.baseFontSize = baseFontSize
        self.showGrid = showGrid
        self.showLegend = showLegend
        self.showScale = showScale
        self.showGrainSizeScale = showGrainSizeScale
        self.showLogTitle = showLogTitle
        self.showUSGSCodesInLithologyLabels = showUSGSCodesInLithologyLabels
        self.symbolScale = symbolScale
        self.pointFeatureIconSize = pointFeatureIconSize
        self.depthScaleUnit = depthScaleUnit
        self.useAbsoluteAltitude = useAbsoluteAltitude
        self.zeroLevelAltitudeMeters = zeroLevelAltitudeMeters
    }

    enum CodingKeys: String, CodingKey {
        case verticalScale
        case baseFontSize
        case showGrid
        case showLegend
        case showScale
        case showGrainSizeScale
        case showLogTitle
        case showUSGSCodesInLithologyLabels
        case symbolScale
        case pointFeatureIconSize
        case depthScaleUnit
        case useAbsoluteAltitude
        case zeroLevelAltitudeMeters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        verticalScale = try container.decodeIfPresent(Double.self, forKey: .verticalScale) ?? 25
        baseFontSize = try container.decodeIfPresent(Double.self, forKey: .baseFontSize) ?? 12
        showGrid = try container.decodeIfPresent(Bool.self, forKey: .showGrid) ?? false
        showLegend = try container.decodeIfPresent(Bool.self, forKey: .showLegend) ?? true
        showScale = try container.decodeIfPresent(Bool.self, forKey: .showScale) ?? true
        showGrainSizeScale = try container.decodeIfPresent(Bool.self, forKey: .showGrainSizeScale) ?? true
        showLogTitle = try container.decodeIfPresent(Bool.self, forKey: .showLogTitle) ?? true
        showUSGSCodesInLithologyLabels = try container.decodeIfPresent(Bool.self, forKey: .showUSGSCodesInLithologyLabels) ?? true
        symbolScale = try container.decodeIfPresent(Double.self, forKey: .symbolScale) ?? 1.0
        pointFeatureIconSize = try container.decodeIfPresent(Double.self, forKey: .pointFeatureIconSize) ?? 8.0
        depthScaleUnit = try container.decodeIfPresent(DepthScaleUnit.self, forKey: .depthScaleUnit) ?? .meter
        useAbsoluteAltitude = try container.decodeIfPresent(Bool.self, forKey: .useAbsoluteAltitude) ?? false
        zeroLevelAltitudeMeters = try container.decodeIfPresent(Double.self, forKey: .zeroLevelAltitudeMeters)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(verticalScale, forKey: .verticalScale)
        try container.encode(baseFontSize, forKey: .baseFontSize)
        try container.encode(showGrid, forKey: .showGrid)
        try container.encode(showLegend, forKey: .showLegend)
        try container.encode(showScale, forKey: .showScale)
        try container.encode(showGrainSizeScale, forKey: .showGrainSizeScale)
        try container.encode(showLogTitle, forKey: .showLogTitle)
        try container.encode(showUSGSCodesInLithologyLabels, forKey: .showUSGSCodesInLithologyLabels)
        try container.encode(symbolScale, forKey: .symbolScale)
        try container.encode(pointFeatureIconSize, forKey: .pointFeatureIconSize)
        try container.encode(depthScaleUnit, forKey: .depthScaleUnit)
        try container.encode(useAbsoluteAltitude, forKey: .useAbsoluteAltitude)
        try container.encodeIfPresent(zeroLevelAltitudeMeters, forKey: .zeroLevelAltitudeMeters)
    }
}

// Note: Custom field functionality has been removed from the data model.
/// Root document persisted to disk. Contains one or more logs.
public struct ProjectDocument: Codable, Hashable {
    public var logs: [Project]

    public init(logs: [Project] = [Project()]) {
        self.logs = logs.isEmpty ? [Project()] : logs
    }
}

/// Root aggregate persisted to disk and edited in the UI.
public struct Project: Codable, Hashable {
    public var metadata: ProjectMetadata
    public var settings: ProjectSettings
    public var units: [StratigraphicUnit]

    public init(
        metadata: ProjectMetadata = ProjectMetadata(),
        settings: ProjectSettings = ProjectSettings(),
        units: [StratigraphicUnit] = []
    ) {
        self.metadata = metadata
        self.settings = settings
        self.units = units
    }

    public static var sample: Project {
        Project(
            metadata: ProjectMetadata(title: "Example Core Log", author: "Geologist"),
            settings: ProjectSettings(),
            units: [
                StratigraphicUnit(name: "Topsoil", thickness: 0.8, usgsLithologyCode: 619, grainSize: .silt),
                StratigraphicUnit(name: "Channel Sand", thickness: 3.2, usgsLithologyCode: 607, grainSize: .sand),
                StratigraphicUnit(name: "Limestone Bed", thickness: 1.4, usgsLithologyCode: 627, grainSize: .granule)
            ]
        )
    }
}
