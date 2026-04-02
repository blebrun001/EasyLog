import Foundation

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

public enum PointFeatureSymbol: String, Codable, CaseIterable, Hashable {
    case diamond
    case square
    case triangle
    case circle
    case cross
    case plus
}

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
        switch self {
        case .paleoMacroFossils, .paleoMicrofossils, .paleoShellFragments, .paleoPlantRemains, .paleoRoots, .paleoBurrowsBioturbation, .paleoIchnofossils, .paleoCharcoalOrganicMatter:
            return .diamond
        case .diageneticNodules, .diageneticConcretions, .diageneticGeodes, .diageneticLithicInclusions, .diageneticDispersedPebbles, .diageneticReworkedFragments, .diageneticIntraclasts, .diageneticStylolites, .diageneticVeins:
            return .square
        case .localLaminations, .localCrossBedding, .localIsolatedRipples, .localDesiccationCracks, .localLoadStructures, .localSoftSedimentDeformation:
            return .triangle
        case .pedogenesisOxidationSpots, .pedogenesisMottling, .pedogenesisPedologicalHorizons, .pedogenesisCarbonateAccumulations, .pedogenesisCrusts:
            return .circle
        case .archaeologicalArtifacts, .archaeologicalBoneFragments, .archaeologicalAnthropicCharcoal, .archaeologicalPunctualStructures:
            return .cross
        case .hydroCementedZones, .hydroLocalizedMineralPrecipitation, .hydroDissolutionTraces, .hydroFeMnEnrichedLevels:
            return .plus
        }
    }
}

public struct UnitPointFeature: Identifiable, Codable, Hashable {
    public var id: UUID
    public var type: PointFeatureType
    public var concentration: PointFeatureConcentration

    public init(
        id: UUID = UUID(),
        type: PointFeatureType,
        concentration: PointFeatureConcentration
    ) {
        self.id = id
        self.type = type
        self.concentration = concentration
    }
}

public struct StratigraphicUnit: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var thickness: Double
    public var lithology: String
    public var grainSize: USGSGrainSize?
    public var pointFeatures: [UnitPointFeature]

    public init(
        id: UUID = UUID(),
        name: String,
        thickness: Double,
        lithology: String,
        grainSize: USGSGrainSize? = nil,
        pointFeatures: [UnitPointFeature] = []
    ) {
        self.id = id
        self.name = name
        self.thickness = thickness
        self.lithology = lithology
        self.grainSize = grainSize
        self.pointFeatures = pointFeatures
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case thickness
        case lithology
        case grainSize
        case pointFeatures
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        thickness = try container.decode(Double.self, forKey: .thickness)
        lithology = try container.decode(String.self, forKey: .lithology)
        grainSize = try container.decodeIfPresent(USGSGrainSize.self, forKey: .grainSize)
        pointFeatures = try container.decodeIfPresent([UnitPointFeature].self, forKey: .pointFeatures) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(thickness, forKey: .thickness)
        try container.encode(lithology, forKey: .lithology)
        try container.encodeIfPresent(grainSize, forKey: .grainSize)
        try container.encode(pointFeatures, forKey: .pointFeatures)
    }
}

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

public enum PageSizePreset: String, Codable, CaseIterable, Identifiable {
    case a4Portrait
    case letterPortrait

    public var id: String { rawValue }

    public var canvasSize: CGSizeDTO {
        switch self {
        case .a4Portrait:
            return CGSizeDTO(width: 794, height: 1123)
        case .letterPortrait:
            return CGSizeDTO(width: 816, height: 1056)
        }
    }

    public var label: String {
        switch self {
        case .a4Portrait: return "A4 Portrait"
        case .letterPortrait: return "Letter Portrait"
        }
    }
}

public struct CGSizeDTO: Codable, Hashable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct ProjectSettings: Codable, Hashable {
    public var verticalScale: Double
    public var pageSize: PageSizePreset
    public var baseFontSize: Double
    public var showGrid: Bool
    public var symbolScale: Double

    public init(
        verticalScale: Double = 25,
        pageSize: PageSizePreset = .a4Portrait,
        baseFontSize: Double = 12,
        showGrid: Bool = false,
        symbolScale: Double = 1.0
    ) {
        self.verticalScale = verticalScale
        self.pageSize = pageSize
        self.baseFontSize = baseFontSize
        self.showGrid = false
        self.symbolScale = symbolScale
    }

    enum CodingKeys: String, CodingKey {
        case verticalScale
        case pageSize
        case baseFontSize
        case showGrid
        case symbolScale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        verticalScale = try container.decodeIfPresent(Double.self, forKey: .verticalScale) ?? 25
        pageSize = try container.decodeIfPresent(PageSizePreset.self, forKey: .pageSize) ?? .a4Portrait
        baseFontSize = try container.decodeIfPresent(Double.self, forKey: .baseFontSize) ?? 12
        showGrid = false
        symbolScale = try container.decodeIfPresent(Double.self, forKey: .symbolScale) ?? 1.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(verticalScale, forKey: .verticalScale)
        try container.encode(pageSize, forKey: .pageSize)
        try container.encode(baseFontSize, forKey: .baseFontSize)
        try container.encode(false, forKey: .showGrid)
        try container.encode(symbolScale, forKey: .symbolScale)
    }
}

// Note: Custom field functionality has been removed from the data model.
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
                StratigraphicUnit(name: "Topsoil", thickness: 0.8, lithology: "Sandy or silty shale", grainSize: .silt),
                StratigraphicUnit(name: "Channel Sand", thickness: 3.2, lithology: "Massive sand or sandstone", grainSize: .sand),
                StratigraphicUnit(name: "Limestone Bed", thickness: 1.4, lithology: "Limestone", grainSize: .granule)
            ]
        )
    }
}
