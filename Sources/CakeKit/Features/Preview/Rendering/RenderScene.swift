import Foundation

/// Converts domain project data into drawable scene data.
public protocol LogRenderer {
    func makeScene(project: Project) -> RenderScene
}

/// Double-precision rectangle used by geometry computations.
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

/// Render-ready unit geometry and style metadata.
public struct RenderedUnit: Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var thickness: Double
    public var lithology: String
    public var symbol: SymbolPattern
    public var usgsSymbolCode: Int?
    public var rect: RectD
    public var grainSize: USGSGrainSize?
    public var pointFeatures: [RenderedPointFeature]

    public init(
        id: UUID,
        name: String,
        thickness: Double,
        lithology: String,
        symbol: SymbolPattern,
        usgsSymbolCode: Int? = nil,
        rect: RectD,
        grainSize: USGSGrainSize? = nil,
        pointFeatures: [RenderedPointFeature] = []
    ) {
        self.id = id
        self.name = name
        self.thickness = thickness
        self.lithology = lithology
        self.symbol = symbol
        self.usgsSymbolCode = usgsSymbolCode
        self.rect = rect
        self.grainSize = grainSize
        self.pointFeatures = pointFeatures
    }
}

/// Render-ready point feature marker placed inside a unit rectangle.
public struct RenderedPointFeature: Hashable {
    public var type: PointFeatureType
    public var symbol: PointFeatureSymbol
    public var centerX: Double
    public var centerY: Double
    public var size: Double

    public init(
        type: PointFeatureType,
        symbol: PointFeatureSymbol,
        centerX: Double,
        centerY: Double,
        size: Double
    ) {
        self.type = type
        self.symbol = symbol
        self.centerX = centerX
        self.centerY = centerY
        self.size = size
    }
}

/// One legend line item for lithology or point-feature symbols.
public struct LegendItem: Hashable {
    public var label: String
    public var symbol: SymbolPattern
    public var usgsSymbolCode: Int?
    public var pointSymbol: PointFeatureSymbol?

    public init(
        label: String,
        symbol: SymbolPattern,
        usgsSymbolCode: Int? = nil,
        pointSymbol: PointFeatureSymbol? = nil
    ) {
        self.label = label
        self.symbol = symbol
        self.usgsSymbolCode = usgsSymbolCode
        self.pointSymbol = pointSymbol
    }
}

/// Depth axis tick for the current scale unit.
public struct ScaleTick: Hashable {
    public var depth: Double
    public var y: Double

    public init(depth: Double, y: Double) {
        self.depth = depth
        self.y = y
    }
}

/// Immutable render snapshot consumed by SwiftUI preview and exporters.
public struct RenderScene: Hashable {
    public var title: String
    public var canvasSize: CGSizeDTO
    public var logColumnRect: RectD
    public var units: [RenderedUnit]
    public var legend: [LegendItem]
    public var ticks: [ScaleTick]
    public var baseFontSize: Double
    public var showsGrid: Bool
    public var showsLegend: Bool
    public var showsScale: Bool
    public var showsLogTitle: Bool
    public var symbolScale: Double
    public var depthScaleUnit: DepthScaleUnit

    public init(
        title: String,
        canvasSize: CGSizeDTO,
        logColumnRect: RectD,
        units: [RenderedUnit],
        legend: [LegendItem],
        ticks: [ScaleTick],
        baseFontSize: Double,
        showsGrid: Bool,
        showsLegend: Bool,
        showsScale: Bool,
        showsLogTitle: Bool,
        symbolScale: Double,
        depthScaleUnit: DepthScaleUnit
    ) {
        self.title = title
        self.canvasSize = canvasSize
        self.logColumnRect = logColumnRect
        self.units = units
        self.legend = legend
        self.ticks = ticks
        self.baseFontSize = baseFontSize
        self.showsGrid = showsGrid
        self.showsLegend = showsLegend
        self.showsScale = showsScale
        self.showsLogTitle = showsLogTitle
        self.symbolScale = symbolScale
        self.depthScaleUnit = depthScaleUnit
    }

    public static var empty: RenderScene {
        RenderScene(
            title: "Stratigraphic Log",
            canvasSize: CGSizeDTO(width: 900, height: 1200),
            logColumnRect: RectD(x: 120, y: 80, width: 180, height: 1000),
            units: [],
            legend: [],
            ticks: [],
            baseFontSize: 12,
            showsGrid: false,
            showsLegend: true,
            showsScale: true,
            showsLogTitle: true,
            symbolScale: 1.0,
            depthScaleUnit: .meter
        )
    }
}
