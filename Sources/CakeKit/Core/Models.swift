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

public struct StratigraphicUnit: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var thickness: Double
    public var lithology: String
    public var grainSize: USGSGrainSize?

    public init(
        id: UUID = UUID(),
        name: String,
        thickness: Double,
        lithology: String,
        grainSize: USGSGrainSize? = nil
    ) {
        self.id = id
        self.name = name
        self.thickness = thickness
        self.lithology = lithology
        self.grainSize = grainSize
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

    public init(
        verticalScale: Double = 25,
        pageSize: PageSizePreset = .a4Portrait,
        baseFontSize: Double = 12,
        showGrid: Bool = true
    ) {
        self.verticalScale = verticalScale
        self.pageSize = pageSize
        self.baseFontSize = baseFontSize
        self.showGrid = showGrid
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
