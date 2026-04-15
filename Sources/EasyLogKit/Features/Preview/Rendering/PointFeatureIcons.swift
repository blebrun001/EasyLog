import CoreGraphics
import Foundation

/// Stable icon identifiers used to render point features.
public enum PointFeatureIconToken: String, Codable, CaseIterable, Hashable, Sendable {
    case fossil
    case microscope
    case shell
    case leaf
    case roots
    case burrow
    case footprint
    case charcoal

    case nodule
    case concretion
    case geode
    case clast
    case pebbles
    case reworked
    case intraclast
    case stylolite
    case vein

    case laminations
    case crossBedding
    case ripples
    case cracks
    case load
    case deformation

    case oxidation
    case mottling
    case horizons
    case carbonate
    case crust

    case artifact
    case bone
    case anthropicCharcoal
    case structurePoint

    case cemented
    case precipitation
    case dissolution
    case feMn
}

/// Central registry for point-feature icon mappings.
public enum PointFeatureIconCatalog {
    public static func token(for type: PointFeatureType) -> PointFeatureIconToken? {
        switch type {
        case .paleoMacroFossils: return .fossil
        case .paleoMicrofossils: return .microscope
        case .paleoShellFragments: return .shell
        case .paleoPlantRemains: return .leaf
        case .paleoRoots: return .roots
        case .paleoBurrowsBioturbation: return .burrow
        case .paleoIchnofossils: return .footprint
        case .paleoCharcoalOrganicMatter: return .charcoal

        case .diageneticNodules: return .nodule
        case .diageneticConcretions: return .concretion
        case .diageneticGeodes: return .geode
        case .diageneticLithicInclusions: return .clast
        case .diageneticDispersedPebbles: return .pebbles
        case .diageneticReworkedFragments: return .reworked
        case .diageneticIntraclasts: return .intraclast
        case .diageneticStylolites: return .stylolite
        case .diageneticVeins: return .vein

        case .localLaminations: return .laminations
        case .localCrossBedding: return .crossBedding
        case .localIsolatedRipples: return .ripples
        case .localDesiccationCracks: return .cracks
        case .localLoadStructures: return .load
        case .localSoftSedimentDeformation: return .deformation

        case .pedogenesisOxidationSpots: return .oxidation
        case .pedogenesisMottling: return .mottling
        case .pedogenesisPedologicalHorizons: return .horizons
        case .pedogenesisCarbonateAccumulations: return .carbonate
        case .pedogenesisCrusts: return .crust

        case .archaeologicalArtifacts: return .artifact
        case .archaeologicalBoneFragments: return .bone
        case .archaeologicalAnthropicCharcoal: return .anthropicCharcoal
        case .archaeologicalPunctualStructures: return .structurePoint

        case .hydroCementedZones: return .cemented
        case .hydroLocalizedMineralPrecipitation: return .precipitation
        case .hydroDissolutionTraces: return .dissolution
        case .hydroFeMnEnrichedLevels: return .feMn
        }
    }
}

/// Shared icon renderer used by raster and SVG exports.
public enum PointFeatureIconRenderer {
    public static func draw(
        token: PointFeatureIconToken,
        center: CGPoint,
        size: CGFloat,
        strokeColor: CGColor,
        fillColor: CGColor,
        context: CGContext,
        lineWidth: CGFloat = 1.1
    ) -> Bool {
        let half = size / 2
        context.saveGState()
        context.setStrokeColor(strokeColor)
        context.setFillColor(fillColor)
        context.setLineWidth(lineWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        switch token {
        case .fossil:
            drawSpiral(center: center, radius: half * 0.92, context: context)
        case .microscope:
            drawMicroscope(center: center, half: half, context: context)
        case .shell:
            drawShell(center: center, half: half, context: context)
        case .leaf:
            drawLeaf(center: center, half: half, context: context)
        case .roots:
            drawRoots(center: center, half: half, context: context)
        case .burrow:
            drawBurrow(center: center, half: half, context: context)
        case .footprint:
            drawFootprint(center: center, half: half, context: context)
        case .charcoal:
            drawCharcoal(center: center, half: half, context: context)

        case .nodule:
            drawFilledCircle(center: center, radius: half * 0.45, context: context)
        case .concretion:
            drawConcretion(center: center, half: half, context: context)
        case .geode:
            drawGeode(center: center, half: half, context: context)
        case .clast:
            drawClast(center: center, half: half, context: context)
        case .pebbles:
            drawPebbles(center: center, half: half, context: context)
        case .reworked:
            drawReworked(center: center, half: half, context: context)
        case .intraclast:
            drawIntraclast(center: center, half: half, context: context)
        case .stylolite:
            drawStylolite(center: center, half: half, context: context)
        case .vein:
            drawVein(center: center, half: half, context: context)

        case .laminations:
            drawLaminations(center: center, half: half, context: context)
        case .crossBedding:
            drawCrossBedding(center: center, half: half, context: context)
        case .ripples:
            drawRipples(center: center, half: half, context: context)
        case .cracks:
            drawCracks(center: center, half: half, context: context)
        case .load:
            drawLoad(center: center, half: half, context: context)
        case .deformation:
            drawDeformation(center: center, half: half, context: context)

        case .oxidation:
            drawOxidation(center: center, half: half, context: context)
        case .mottling:
            drawMottling(center: center, half: half, context: context)
        case .horizons:
            drawHorizons(center: center, half: half, context: context)
        case .carbonate:
            drawCarbonate(center: center, half: half, context: context)
        case .crust:
            drawCrust(center: center, half: half, context: context)

        case .artifact:
            drawArtifact(center: center, half: half, context: context)
        case .bone:
            drawBone(center: center, half: half, context: context)
        case .anthropicCharcoal:
            drawAnthropicCharcoal(center: center, half: half, context: context)
        case .structurePoint:
            drawStructurePoint(center: center, half: half, context: context)

        case .cemented:
            drawCemented(center: center, half: half, context: context)
        case .precipitation:
            drawPrecipitation(center: center, half: half, context: context)
        case .dissolution:
            drawDissolution(center: center, half: half, context: context)
        case .feMn:
            drawFeMn(center: center, half: half, context: context)
        }

        context.restoreGState()
        return true
    }

    public static func svgElement(
        token: PointFeatureIconToken,
        colorHex: String,
        centerX: Double,
        centerY: Double,
        size: Double,
        strokeWidth: Double = 1.1
    ) -> String? {
        let half = size / 2
        let stroke = "stroke=\"\(colorHex)\" stroke-opacity=\"0.95\" stroke-width=\"\(fmt(strokeWidth))\""
        let fill = "fill=\"\(colorHex)\" fill-opacity=\"0.18\""

        func p(_ x: Double, _ y: Double) -> String {
            "\(fmt(centerX + x * half)) \(fmt(centerY + y * half))"
        }

        switch token {
        case .fossil:
            return "<circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY))\" r=\"\(fmt(half * 0.75))\" fill=\"none\" \(stroke)/><circle cx=\"\(fmt(centerX + half * 0.25))\" cy=\"\(fmt(centerY + half * 0.05))\" r=\"\(fmt(half * 0.22))\" \(fill) \(stroke)/>"
        case .microscope:
            return "<path d=\"M \(p(-0.45,0.45)) L \(p(0.15,0.45)) M \(p(-0.2,0.45)) L \(p(0.2,-0.1)) M \(p(-0.1,-0.2)) L \(p(0.25,-0.2)) M \(p(0.25,-0.2)) L \(p(0.35,-0.35))\" fill=\"none\" \(stroke)/>"
        case .shell:
            return "<path d=\"M \(p(-0.5,0.35)) Q \(p(0,-0.6)) \(p(0.5,0.35)) M \(p(-0.2,0.2)) L \(p(0.2,0.2)) M \(p(-0.35,0.32)) L \(p(0.35,0.32))\" \(fill) \(stroke)/>"
        case .leaf:
            return "<path d=\"M \(p(0,-0.55)) Q \(p(0.6,0)) \(p(0,0.55)) Q \(p(-0.6,0)) \(p(0,-0.55)) Z M \(p(0,-0.45)) L \(p(0,0.45))\" \(fill) \(stroke)/>"
        case .roots:
            return "<path d=\"M \(p(0,-0.5)) L \(p(0,0.05)) M \(p(0,0.05)) L \(p(-0.35,0.5)) M \(p(0,0.05)) L \(p(0.35,0.5)) M \(p(0,0.15)) L \(p(0,0.5))\" fill=\"none\" \(stroke)/>"
        case .burrow:
            return "<path d=\"M \(p(-0.5,0.15)) C \(p(-0.2,-0.45)) \(p(0.2,0.45)) \(p(0.5,-0.1))\" fill=\"none\" \(stroke)/>"
        case .footprint:
            return "<ellipse cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY + half * 0.1))\" rx=\"\(fmt(half * 0.25))\" ry=\"\(fmt(half * 0.35))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX - half * 0.28))\" cy=\"\(fmt(centerY - half * 0.2))\" r=\"\(fmt(half * 0.1))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY - half * 0.28))\" r=\"\(fmt(half * 0.1))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX + half * 0.28))\" cy=\"\(fmt(centerY - half * 0.2))\" r=\"\(fmt(half * 0.1))\" \(fill) \(stroke)/>"
        case .charcoal:
            return "<path d=\"M \(p(-0.4,0.45)) L \(p(-0.1,-0.45)) L \(p(0.1,-0.45)) L \(p(0.4,0.45)) Z\" \(fill) \(stroke)/>"

        case .nodule:
            return "<circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY))\" r=\"\(fmt(half * 0.45))\" \(fill) \(stroke)/>"
        case .concretion:
            return "<circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY))\" r=\"\(fmt(half * 0.5))\" fill=\"none\" \(stroke)/><circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY))\" r=\"\(fmt(half * 0.22))\" \(fill) \(stroke)/>"
        case .geode:
            return "<path d=\"M \(p(0,-0.55)) L \(p(0.5,-0.15)) L \(p(0.32,0.5)) L \(p(-0.32,0.5)) L \(p(-0.5,-0.15)) Z\" \(fill) \(stroke)/>"
        case .clast:
            return "<path d=\"M \(p(-0.45,-0.1)) L \(p(-0.1,-0.5)) L \(p(0.45,-0.2)) L \(p(0.2,0.5)) L \(p(-0.4,0.35)) Z\" \(fill) \(stroke)/>"
        case .pebbles:
            return "<circle cx=\"\(fmt(centerX - half * 0.2))\" cy=\"\(fmt(centerY - half * 0.15))\" r=\"\(fmt(half * 0.2))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX + half * 0.2))\" cy=\"\(fmt(centerY + half * 0.1))\" r=\"\(fmt(half * 0.18))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY + half * 0.32))\" r=\"\(fmt(half * 0.14))\" \(fill) \(stroke)/>"
        case .reworked:
            return "<path d=\"M \(p(-0.4,-0.05)) L \(p(0.35,-0.05)) M \(p(0.15,-0.25)) L \(p(0.35,-0.05)) L \(p(0.15,0.15))\" fill=\"none\" \(stroke)/>"
        case .intraclast:
            return "<path d=\"M \(p(-0.35,-0.35)) L \(p(0.1,-0.45)) L \(p(0.4,-0.05)) L \(p(0.15,0.4)) L \(p(-0.3,0.3)) Z\" \(fill) \(stroke)/>"
        case .stylolite:
            return "<path d=\"M \(p(-0.5,0)) L \(p(-0.3,-0.2)) L \(p(-0.1,0.2)) L \(p(0.1,-0.2)) L \(p(0.3,0.2)) L \(p(0.5,0))\" fill=\"none\" \(stroke)/>"
        case .vein:
            return "<path d=\"M \(p(-0.45,0.35)) L \(p(-0.05,-0.45)) L \(p(0.45,0.4))\" fill=\"none\" \(stroke)/>"

        case .laminations:
            return "<path d=\"M \(p(-0.5,-0.25)) L \(p(0.5,-0.25)) M \(p(-0.5,0)) L \(p(0.5,0)) M \(p(-0.5,0.25)) L \(p(0.5,0.25))\" fill=\"none\" \(stroke)/>"
        case .crossBedding:
            return "<path d=\"M \(p(-0.45,0.35)) L \(p(0.45,-0.35)) M \(p(-0.45,0.1)) L \(p(0.2,-0.35)) M \(p(-0.2,0.35)) L \(p(0.45,-0.1))\" fill=\"none\" \(stroke)/>"
        case .ripples:
            return "<path d=\"M \(p(-0.5,-0.2)) C \(p(-0.25,-0.35)) \(p(0,-0.05)) \(p(0.25,-0.2)) C \(p(0.35,-0.25)) \(p(0.45,-0.25)) \(p(0.5,-0.2)) M \(p(-0.5,0.2)) C \(p(-0.25,0.05)) \(p(0,0.35)) \(p(0.25,0.2)) C \(p(0.35,0.15)) \(p(0.45,0.15)) \(p(0.5,0.2))\" fill=\"none\" \(stroke)/>"
        case .cracks:
            return "<path d=\"M \(p(0,-0.5)) L \(p(0,0.5)) M \(p(0,-0.05)) L \(p(-0.35,-0.3)) M \(p(0,0.1)) L \(p(0.35,0.35))\" fill=\"none\" \(stroke)/>"
        case .load:
            return "<path d=\"M \(p(-0.5,-0.2)) L \(p(0.5,-0.2)) M \(p(-0.35,-0.2)) Q \(p(-0.2,0.35)) \(p(-0.05,-0.2)) M \(p(0.05,-0.2)) Q \(p(0.2,0.35)) \(p(0.35,-0.2))\" fill=\"none\" \(stroke)/>"
        case .deformation:
            return "<path d=\"M \(p(-0.5,-0.15)) C \(p(-0.2,-0.55)) \(p(0.2,0.25)) \(p(0.5,-0.15)) M \(p(-0.5,0.2)) C \(p(-0.2,-0.2)) \(p(0.2,0.6)) \(p(0.5,0.2))\" fill=\"none\" \(stroke)/>"

        case .oxidation:
            return "<circle cx=\"\(fmt(centerX - half * 0.2))\" cy=\"\(fmt(centerY - half * 0.12))\" r=\"\(fmt(half * 0.12))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX + half * 0.18))\" cy=\"\(fmt(centerY + half * 0.08))\" r=\"\(fmt(half * 0.16))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY + half * 0.3))\" r=\"\(fmt(half * 0.1))\" \(fill) \(stroke)/>"
        case .mottling:
            return "<ellipse cx=\"\(fmt(centerX - half * 0.2))\" cy=\"\(fmt(centerY))\" rx=\"\(fmt(half * 0.28))\" ry=\"\(fmt(half * 0.16))\" \(fill) \(stroke)/><ellipse cx=\"\(fmt(centerX + half * 0.2))\" cy=\"\(fmt(centerY + half * 0.12))\" rx=\"\(fmt(half * 0.22))\" ry=\"\(fmt(half * 0.14))\" \(fill) \(stroke)/>"
        case .horizons:
            return "<path d=\"M \(p(-0.5,-0.25)) L \(p(0.5,-0.25)) M \(p(-0.5,0)) L \(p(0.5,0)) M \(p(-0.5,0.25)) L \(p(0.5,0.25))\" fill=\"none\" \(stroke)/>"
        case .carbonate:
            return "<circle cx=\"\(fmt(centerX))\" cy=\"\(fmt(centerY))\" r=\"\(fmt(half * 0.36))\" fill=\"none\" \(stroke)/><path d=\"M \(p(-0.26,0)) L \(p(0.26,0)) M \(p(0,-0.26)) L \(p(0,0.26))\" fill=\"none\" \(stroke)/>"
        case .crust:
            return "<path d=\"M \(p(-0.5,0.15)) L \(p(-0.2,-0.15)) L \(p(0,-0.05)) L \(p(0.2,-0.2)) L \(p(0.5,0.1))\" fill=\"none\" \(stroke)/>"

        case .artifact:
            return "<path d=\"M \(p(-0.4,0.3)) L \(p(0.1,-0.45)) L \(p(0.35,-0.35)) L \(p(-0.15,0.4)) Z\" \(fill) \(stroke)/>"
        case .bone:
            return "<circle cx=\"\(fmt(centerX - half * 0.22))\" cy=\"\(fmt(centerY - half * 0.22))\" r=\"\(fmt(half * 0.14))\" \(fill) \(stroke)/><circle cx=\"\(fmt(centerX + half * 0.22))\" cy=\"\(fmt(centerY + half * 0.22))\" r=\"\(fmt(half * 0.14))\" \(fill) \(stroke)/><path d=\"M \(p(-0.15,-0.15)) L \(p(0.15,0.15))\" fill=\"none\" \(stroke)/>"
        case .anthropicCharcoal:
            return "<path d=\"M \(p(-0.1,0.5)) L \(p(-0.1,-0.05)) M \(p(0.1,0.5)) L \(p(0.1,-0.05)) M \(p(-0.22,-0.05)) L \(p(0.22,-0.05)) M \(p(0,0.08)) L \(p(0,-0.48))\" fill=\"none\" \(stroke)/>"
        case .structurePoint:
            return "<path d=\"M \(p(0,-0.45)) L \(p(0.35,-0.05)) L \(p(0,0.5)) L \(p(-0.35,-0.05)) Z\" \(fill) \(stroke)/>"

        case .cemented:
            return "<rect x=\"\(fmt(centerX - half * 0.45))\" y=\"\(fmt(centerY - half * 0.35))\" width=\"\(fmt(half * 0.9))\" height=\"\(fmt(half * 0.7))\" \(fill) \(stroke)/><path d=\"M \(p(-0.45,0)) L \(p(0.45,0))\" fill=\"none\" \(stroke)/>"
        case .precipitation:
            return "<path d=\"M \(p(0,-0.5)) L \(p(0.18,-0.1)) L \(p(0,0.2)) L \(p(-0.18,-0.1)) Z\" \(fill) \(stroke)/><path d=\"M \(p(-0.35,0.35)) L \(p(0.35,0.35))\" fill=\"none\" \(stroke)/>"
        case .dissolution:
            return "<path d=\"M \(p(-0.3,-0.3)) Q \(p(0,-0.5)) \(p(0.3,-0.3)) Q \(p(0.12,0.25)) \(p(0,0.45)) Q \(p(-0.12,0.25)) \(p(-0.3,-0.3)) Z M \(p(-0.2,0.35)) L \(p(0.2,-0.15))\" \(fill) \(stroke)/>"
        case .feMn:
            return "<path d=\"M \(p(-0.35,-0.15)) L \(p(0.1,-0.15)) M \(p(-0.35,0.2)) L \(p(0.05,0.2)) M \(p(0.2,-0.2)) L \(p(0.35,-0.2)) L \(p(0.35,0.25))\" fill=\"none\" \(stroke)/>"
        }
    }

    private static func fmt(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.3f", value)
    }

    private static func drawFilledCircle(center: CGPoint, radius: CGFloat, context: CGContext) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fillEllipse(in: rect)
        context.strokeEllipse(in: rect)
    }

    private static func drawSpiral(center: CGPoint, radius: CGFloat, context: CGContext) {
        let turns = 2.3
        let segments = 40
        context.beginPath()
        for i in 0...segments {
            let t = CGFloat(Double(i) / Double(segments))
            let angle = CGFloat(turns * 2 * .pi) * t
            let r = radius * t
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            if i == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.strokePath()
    }

    private static func drawMicroscope(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y + half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.15, y: center.y + half * 0.45))
        context.move(to: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y - half * 0.1))
        context.move(to: CGPoint(x: center.x - half * 0.1, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.25, y: center.y - half * 0.2))
        context.move(to: CGPoint(x: center.x + half * 0.25, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.35))
        context.strokePath()
    }

    private static func drawShell(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.35))
        context.addQuadCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y + half * 0.35), control: CGPoint(x: center.x, y: center.y - half * 0.6))
        context.strokePath()
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y + half * 0.32))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y + half * 0.32))
        context.move(to: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.2))
        context.strokePath()
    }

    private static func drawLeaf(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.55))
        context.addQuadCurve(to: CGPoint(x: center.x, y: center.y + half * 0.55), control: CGPoint(x: center.x + half * 0.6, y: center.y))
        context.addQuadCurve(to: CGPoint(x: center.x, y: center.y - half * 0.55), control: CGPoint(x: center.x - half * 0.6, y: center.y))
        context.closePath()
        context.drawPath(using: .fillStroke)
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.45))
        context.strokePath()
    }

    private static func drawRoots(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.5))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.05))
        context.move(to: CGPoint(x: center.x, y: center.y + half * 0.05))
        context.addLine(to: CGPoint(x: center.x - half * 0.35, y: center.y + half * 0.5))
        context.move(to: CGPoint(x: center.x, y: center.y + half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y + half * 0.5))
        context.move(to: CGPoint(x: center.x, y: center.y + half * 0.15))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.5))
        context.strokePath()
    }

    private static func drawBurrow(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.15))
        context.addCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.1), control1: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.45), control2: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.45))
        context.strokePath()
    }

    private static func drawFootprint(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: CGPoint(x: center.x, y: center.y + half * 0.1), radius: half * 0.22, context: context)
        drawFilledCircle(center: CGPoint(x: center.x - half * 0.28, y: center.y - half * 0.2), radius: half * 0.1, context: context)
        drawFilledCircle(center: CGPoint(x: center.x, y: center.y - half * 0.28), radius: half * 0.1, context: context)
        drawFilledCircle(center: CGPoint(x: center.x + half * 0.28, y: center.y - half * 0.2), radius: half * 0.1, context: context)
    }

    private static func drawCharcoal(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.4, y: center.y + half * 0.45))
        context.addLine(to: CGPoint(x: center.x - half * 0.1, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.4, y: center.y + half * 0.45))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawConcretion(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: center, radius: half * 0.5, context: context)
        drawFilledCircle(center: center, radius: half * 0.22, context: context)
    }

    private static func drawGeode(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.55))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.15))
        context.addLine(to: CGPoint(x: center.x + half * 0.32, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x - half * 0.32, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x - half * 0.5, y: center.y - half * 0.15))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawClast(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y - half * 0.1))
        context.addLine(to: CGPoint(x: center.x - half * 0.1, y: center.y - half * 0.5))
        context.addLine(to: CGPoint(x: center.x + half * 0.45, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x - half * 0.4, y: center.y + half * 0.35))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawPebbles(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.15), radius: half * 0.2, context: context)
        drawFilledCircle(center: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.1), radius: half * 0.18, context: context)
        drawFilledCircle(center: CGPoint(x: center.x, y: center.y + half * 0.32), radius: half * 0.14, context: context)
    }

    private static func drawReworked(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.4, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.05))
        context.move(to: CGPoint(x: center.x + half * 0.15, y: center.y - half * 0.25))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.15, y: center.y + half * 0.15))
        context.strokePath()
    }

    private static func drawIntraclast(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y - half * 0.35))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.4, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.15, y: center.y + half * 0.4))
        context.addLine(to: CGPoint(x: center.x - half * 0.3, y: center.y + half * 0.3))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawStylolite(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y))
        context.addLine(to: CGPoint(x: center.x - half * 0.3, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x - half * 0.1, y: center.y + half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.3, y: center.y + half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y))
        context.strokePath()
    }

    private static func drawVein(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y + half * 0.35))
        context.addLine(to: CGPoint(x: center.x - half * 0.05, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.45, y: center.y + half * 0.4))
        context.strokePath()
    }

    private static func drawLaminations(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y - half * 0.25))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.25))
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y))
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.25))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y + half * 0.25))
        context.strokePath()
    }

    private static func drawCrossBedding(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y + half * 0.35))
        context.addLine(to: CGPoint(x: center.x + half * 0.45, y: center.y - half * 0.35))
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y + half * 0.1))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y - half * 0.35))
        context.move(to: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.35))
        context.addLine(to: CGPoint(x: center.x + half * 0.45, y: center.y - half * 0.1))
        context.strokePath()
    }

    private static func drawRipples(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y - half * 0.2))
        context.addCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.2), control1: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.45), control2: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.05))
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.2))
        context.addCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y + half * 0.2), control1: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.05), control2: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.45))
        context.strokePath()
    }

    private static func drawCracks(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.5))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.5))
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x - half * 0.35, y: center.y - half * 0.3))
        context.move(to: CGPoint(x: center.x, y: center.y + half * 0.1))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y + half * 0.35))
        context.strokePath()
    }

    private static func drawLoad(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.2))
        context.strokePath()
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y - half * 0.2))
        context.addQuadCurve(to: CGPoint(x: center.x - half * 0.05, y: center.y - half * 0.2), control: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.35))
        context.move(to: CGPoint(x: center.x + half * 0.05, y: center.y - half * 0.2))
        context.addQuadCurve(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.2), control: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.35))
        context.strokePath()
    }

    private static func drawDeformation(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y - half * 0.15))
        context.addCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y - half * 0.15), control1: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.55), control2: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.25))
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.2))
        context.addCurve(to: CGPoint(x: center.x + half * 0.5, y: center.y + half * 0.2), control1: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.2), control2: CGPoint(x: center.x + half * 0.2, y: center.y + half * 0.6))
        context.strokePath()
    }

    private static func drawOxidation(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.12), radius: half * 0.12, context: context)
        drawFilledCircle(center: CGPoint(x: center.x + half * 0.18, y: center.y + half * 0.08), radius: half * 0.16, context: context)
        drawFilledCircle(center: CGPoint(x: center.x, y: center.y + half * 0.3), radius: half * 0.1, context: context)
    }

    private static func drawMottling(center: CGPoint, half: CGFloat, context: CGContext) {
        let a = CGRect(x: center.x - half * 0.48, y: center.y - half * 0.16, width: half * 0.56, height: half * 0.32)
        let b = CGRect(x: center.x - half * 0.02, y: center.y - half * 0.02, width: half * 0.44, height: half * 0.28)
        context.fillEllipse(in: a)
        context.strokeEllipse(in: a)
        context.fillEllipse(in: b)
        context.strokeEllipse(in: b)
    }

    private static func drawHorizons(center: CGPoint, half: CGFloat, context: CGContext) {
        drawLaminations(center: center, half: half, context: context)
    }

    private static func drawCarbonate(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: center, radius: half * 0.36, context: context)
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.26, y: center.y))
        context.addLine(to: CGPoint(x: center.x + half * 0.26, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.26))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.26))
        context.strokePath()
    }

    private static func drawCrust(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.5, y: center.y + half * 0.15))
        context.addLine(to: CGPoint(x: center.x - half * 0.2, y: center.y - half * 0.15))
        context.addLine(to: CGPoint(x: center.x, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.5, y: center.y + half * 0.1))
        context.strokePath()
    }

    private static func drawArtifact(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.4, y: center.y + half * 0.3))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.35))
        context.addLine(to: CGPoint(x: center.x - half * 0.15, y: center.y + half * 0.4))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawBone(center: CGPoint, half: CGFloat, context: CGContext) {
        drawFilledCircle(center: CGPoint(x: center.x - half * 0.22, y: center.y - half * 0.22), radius: half * 0.14, context: context)
        drawFilledCircle(center: CGPoint(x: center.x + half * 0.22, y: center.y + half * 0.22), radius: half * 0.14, context: context)
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.15, y: center.y - half * 0.15))
        context.addLine(to: CGPoint(x: center.x + half * 0.15, y: center.y + half * 0.15))
        context.strokePath()
    }

    private static func drawAnthropicCharcoal(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.1, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x - half * 0.1, y: center.y - half * 0.05))
        context.move(to: CGPoint(x: center.x + half * 0.1, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.05))
        context.move(to: CGPoint(x: center.x - half * 0.22, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x + half * 0.22, y: center.y - half * 0.05))
        context.move(to: CGPoint(x: center.x, y: center.y + half * 0.08))
        context.addLine(to: CGPoint(x: center.x, y: center.y - half * 0.48))
        context.strokePath()
    }

    private static func drawStructurePoint(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.45))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.05))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.5))
        context.addLine(to: CGPoint(x: center.x - half * 0.35, y: center.y - half * 0.05))
        context.closePath()
        context.drawPath(using: .fillStroke)
    }

    private static func drawCemented(center: CGPoint, half: CGFloat, context: CGContext) {
        let rect = CGRect(x: center.x - half * 0.45, y: center.y - half * 0.35, width: half * 0.9, height: half * 0.7)
        context.fill(rect)
        context.stroke(rect)
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.45, y: center.y))
        context.addLine(to: CGPoint(x: center.x + half * 0.45, y: center.y))
        context.strokePath()
    }

    private static func drawPrecipitation(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y - half * 0.5))
        context.addLine(to: CGPoint(x: center.x + half * 0.18, y: center.y - half * 0.1))
        context.addLine(to: CGPoint(x: center.x, y: center.y + half * 0.2))
        context.addLine(to: CGPoint(x: center.x - half * 0.18, y: center.y - half * 0.1))
        context.closePath()
        context.drawPath(using: .fillStroke)
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y + half * 0.35))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y + half * 0.35))
        context.strokePath()
    }

    private static func drawDissolution(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.3, y: center.y - half * 0.3))
        context.addQuadCurve(to: CGPoint(x: center.x + half * 0.3, y: center.y - half * 0.3), control: CGPoint(x: center.x, y: center.y - half * 0.5))
        context.addQuadCurve(to: CGPoint(x: center.x, y: center.y + half * 0.45), control: CGPoint(x: center.x + half * 0.12, y: center.y + half * 0.25))
        context.addQuadCurve(to: CGPoint(x: center.x - half * 0.3, y: center.y - half * 0.3), control: CGPoint(x: center.x - half * 0.12, y: center.y + half * 0.25))
        context.closePath()
        context.drawPath(using: .fillStroke)
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.2, y: center.y + half * 0.35))
        context.addLine(to: CGPoint(x: center.x + half * 0.2, y: center.y - half * 0.15))
        context.strokePath()
    }

    private static func drawFeMn(center: CGPoint, half: CGFloat, context: CGContext) {
        context.beginPath()
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y - half * 0.15))
        context.addLine(to: CGPoint(x: center.x + half * 0.1, y: center.y - half * 0.15))
        context.move(to: CGPoint(x: center.x - half * 0.35, y: center.y + half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.05, y: center.y + half * 0.2))
        context.move(to: CGPoint(x: center.x + half * 0.2, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y - half * 0.2))
        context.addLine(to: CGPoint(x: center.x + half * 0.35, y: center.y + half * 0.25))
        context.strokePath()
    }
}
