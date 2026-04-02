import Foundation

public protocol LogRenderer {
    func makeScene(project: Project) -> RenderScene
}

public struct RectD: Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct RenderedUnit: Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var thickness: Double
    public var lithology: String
    public var symbol: SymbolPattern
    public var rect: RectD
    public var grainSize: USGSGrainSize?

    public init(
        id: UUID,
        name: String,
        thickness: Double,
        lithology: String,
        symbol: SymbolPattern,
        rect: RectD,
        grainSize: USGSGrainSize? = nil
    ) {
        self.id = id
        self.name = name
        self.thickness = thickness
        self.lithology = lithology
        self.symbol = symbol
        self.rect = rect
        self.grainSize = grainSize
    }
}

public struct LegendItem: Hashable {
    public var label: String
    public var symbol: SymbolPattern

    public init(label: String, symbol: SymbolPattern) {
        self.label = label
        self.symbol = symbol
    }
}

public struct ScaleTick: Hashable {
    public var depth: Double
    public var y: Double

    public init(depth: Double, y: Double) {
        self.depth = depth
        self.y = y
    }
}

public struct RenderScene: Hashable {
    public var canvasSize: CGSizeDTO
    public var logColumnRect: RectD
    public var units: [RenderedUnit]
    public var legend: [LegendItem]
    public var ticks: [ScaleTick]
    public var baseFontSize: Double
    public var showsGrid: Bool

    public init(
        canvasSize: CGSizeDTO,
        logColumnRect: RectD,
        units: [RenderedUnit],
        legend: [LegendItem],
        ticks: [ScaleTick],
        baseFontSize: Double,
        showsGrid: Bool
    ) {
        self.canvasSize = canvasSize
        self.logColumnRect = logColumnRect
        self.units = units
        self.legend = legend
        self.ticks = ticks
        self.baseFontSize = baseFontSize
        self.showsGrid = showsGrid
    }

    public static var empty: RenderScene {
        RenderScene(
            canvasSize: CGSizeDTO(width: 900, height: 1200),
            logColumnRect: RectD(x: 120, y: 80, width: 180, height: 1000),
            units: [],
            legend: [],
            ticks: [],
            baseFontSize: 12,
            showsGrid: true
        )
    }
}
