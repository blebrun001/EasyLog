import Foundation

/// Internal hatch/pattern identifiers used by fallback vector drawing.
public enum SymbolPattern: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case sandstone
    case mudstone
    case shale
    case limestone
    case dolostone
    case conglomerate
    case siltstone
    case claystone
    case marl
    case chert
    case coal
    case evaporite
    case fallback

    public var id: String { rawValue }
}

/// Visual style tuple for non-USGS pattern fallback rendering.
public struct SymbologyStyle: Hashable, Sendable {
    public var symbol: SymbolPattern
    public var fillHex: String
    public var strokeHex: String

    public init(symbol: SymbolPattern, fillHex: String, strokeHex: String = "#202020") {
        self.symbol = symbol
        self.fillHex = fillHex
        self.strokeHex = strokeHex
    }
}

/// Catalog entry from FGDC Section 37 (code + canonical lithology label).
public struct USGSLithologySymbol: Hashable, Sendable {
    public let code: Int
    public let label: String

    public init(code: Int, label: String) {
        self.code = code
        self.label = label
    }
}

/// High-level grouping used to organize lithology choices in the UI.
public enum USGSLithologyCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case coarseClastics
    case fineClastics
    case carbonates
    case siliceousBiogenic
    case organicChemical
    case interbedded
    case unconsolidated
    case metamorphic
    case igneousVolcanic
    case mineralization
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .coarseClastics: return "Clastic (Coarse to Sand)"
        case .fineClastics: return "Clastic (Fine-Grained)"
        case .carbonates: return "Carbonates"
        case .siliceousBiogenic: return "Siliceous / Biogenic"
        case .organicChemical: return "Organic / Chemical"
        case .interbedded: return "Interbedded"
        case .unconsolidated: return "Unconsolidated Sediments"
        case .metamorphic: return "Metamorphic"
        case .igneousVolcanic: return "Igneous / Volcanic"
        case .mineralization: return "Mineralization / Ore"
        case .other: return "Other"
        }
    }
}

/// Central lithology/symbol lookup table and USGS metadata registry.
public enum SymbologyLibrary {
    public static let usgsSourceURL = URL(string: "https://pubs.usgs.gov/tm/2006/11A02/")!

    public static let usgsSection37OfficialSymbols: [USGSLithologySymbol] = [
        USGSLithologySymbol(code: 601, label: "Gravel or conglomerate (1st option)"),
        USGSLithologySymbol(code: 602, label: "Gravel or conglomerate (2nd option)"),
        USGSLithologySymbol(code: 603, label: "Crossbedded gravel or conglomerate"),
        USGSLithologySymbol(code: 605, label: "Breccia (1st option)"),
        USGSLithologySymbol(code: 606, label: "Breccia (2nd option)"),
        USGSLithologySymbol(code: 607, label: "Massive sand or sandstone"),
        USGSLithologySymbol(code: 608, label: "Bedded sand or sandstone"),
        USGSLithologySymbol(code: 609, label: "Crossbedded sand or sandstone (1st option)"),
        USGSLithologySymbol(code: 610, label: "Crossbedded sand or sandstone (2nd option)"),
        USGSLithologySymbol(code: 611, label: "Ripple-bedded sand or sandstone"),
        USGSLithologySymbol(code: 612, label: "Argillaceous or shaly sandstone"),
        USGSLithologySymbol(code: 613, label: "Calcareous sandstone"),
        USGSLithologySymbol(code: 614, label: "Dolomitic sandstone"),
        USGSLithologySymbol(code: 616, label: "Silt, siltstone, or shaly silt"),
        USGSLithologySymbol(code: 617, label: "Calcareous siltstone"),
        USGSLithologySymbol(code: 618, label: "Dolomitic siltstone"),
        USGSLithologySymbol(code: 619, label: "Sandy or silty shale"),
        USGSLithologySymbol(code: 620, label: "Clay or clay shale"),
        USGSLithologySymbol(code: 621, label: "Cherty shale"),
        USGSLithologySymbol(code: 622, label: "Dolomitic shale"),
        USGSLithologySymbol(code: 623, label: "Calcareous shale or marl"),
        USGSLithologySymbol(code: 624, label: "Carbonaceous shale"),
        USGSLithologySymbol(code: 625, label: "Oil shale"),
        USGSLithologySymbol(code: 626, label: "Chalk"),
        USGSLithologySymbol(code: 627, label: "Limestone"),
        USGSLithologySymbol(code: 628, label: "Clastic limestone"),
        USGSLithologySymbol(code: 629, label: "Fossiliferous clastic limestone"),
        USGSLithologySymbol(code: 630, label: "Nodular or irregularly bedded limestone"),
        USGSLithologySymbol(code: 631, label: "Limestone, irregular (burrow?) fillings of saccharoidal dolomite"),
        USGSLithologySymbol(code: 632, label: "Crossbedded limestone"),
        USGSLithologySymbol(code: 633, label: "Cherty crossbedded limestone"),
        USGSLithologySymbol(code: 634, label: "Cherty and sandy crossbedded clastic limestone"),
        USGSLithologySymbol(code: 635, label: "Oolitic limestone"),
        USGSLithologySymbol(code: 636, label: "Sandy limestone"),
        USGSLithologySymbol(code: 637, label: "Silty limestone"),
        USGSLithologySymbol(code: 638, label: "Argillaceous or shaly limestone"),
        USGSLithologySymbol(code: 639, label: "Cherty limestone (1st option)"),
        USGSLithologySymbol(code: 640, label: "Cherty limestone (2nd option)"),
        USGSLithologySymbol(code: 641, label: "Dolomitic limestone, limy dolostone, or limy dolomite"),
        USGSLithologySymbol(code: 642, label: "Dolostone or dolomite"),
        USGSLithologySymbol(code: 643, label: "Crossbedded dolostone or dolomite"),
        USGSLithologySymbol(code: 644, label: "Oolitic dolostone or dolomite"),
        USGSLithologySymbol(code: 645, label: "Sandy dolostone or dolomite"),
        USGSLithologySymbol(code: 646, label: "Silty dolostone or dolomite"),
        USGSLithologySymbol(code: 647, label: "Argillaceous or shaly dolostone or dolomite"),
        USGSLithologySymbol(code: 648, label: "Cherty dolostone or dolomite"),
        USGSLithologySymbol(code: 649, label: "Bedded chert (1st option)"),
        USGSLithologySymbol(code: 650, label: "Bedded chert (2nd option)"),
        USGSLithologySymbol(code: 651, label: "Fossiliferous bedded chert"),
        USGSLithologySymbol(code: 652, label: "Fossiliferous rock"),
        USGSLithologySymbol(code: 653, label: "Diatomaceous rock"),
        USGSLithologySymbol(code: 654, label: "Subgraywacke"),
        USGSLithologySymbol(code: 655, label: "Crossbedded subgraywacke"),
        USGSLithologySymbol(code: 656, label: "Ripple-bedded subgraywacke"),
        USGSLithologySymbol(code: 657, label: "Peat"),
        USGSLithologySymbol(code: 658, label: "Coal"),
        USGSLithologySymbol(code: 659, label: "Bony coal or impure coal"),
        USGSLithologySymbol(code: 660, label: "Underclay"),
        USGSLithologySymbol(code: 661, label: "Flint clay"),
        USGSLithologySymbol(code: 662, label: "Bentonite"),
        USGSLithologySymbol(code: 663, label: "Glauconite"),
        USGSLithologySymbol(code: 664, label: "Limonite"),
        USGSLithologySymbol(code: 665, label: "Siderite"),
        USGSLithologySymbol(code: 666, label: "Phosphatic-nodular rock"),
        USGSLithologySymbol(code: 667, label: "Gypsum"),
        USGSLithologySymbol(code: 668, label: "Salt"),
        USGSLithologySymbol(code: 669, label: "Interbedded sandstone and siltstone"),
        USGSLithologySymbol(code: 670, label: "Interbedded sandstone and shale"),
        USGSLithologySymbol(code: 671, label: "Interbedded ripple-bedded sandstone and shale"),
        USGSLithologySymbol(code: 672, label: "Interbedded shale and silty limestone (shale dominant)"),
        USGSLithologySymbol(code: 673, label: "Interbedded shale and limestone (shale dominant) (1st option)"),
        USGSLithologySymbol(code: 674, label: "Interbedded shale and limestone (shale dominant) (2nd option)"),
        USGSLithologySymbol(code: 675, label: "Interbedded calcareous shale and limestone (shale dominant)"),
        USGSLithologySymbol(code: 676, label: "Interbedded silty limestone and shale"),
        USGSLithologySymbol(code: 677, label: "Interbedded limestone and shale (1st option)"),
        USGSLithologySymbol(code: 678, label: "Interbedded limestone and shale (2nd option)"),
        USGSLithologySymbol(code: 679, label: "Interbedded limestone and shale (limestone dominant)"),
        USGSLithologySymbol(code: 680, label: "Interbedded limestone and calcareous shale"),
        USGSLithologySymbol(code: 681, label: "Till or diamicton (1st option)"),
        USGSLithologySymbol(code: 682, label: "Till or diamicton (2nd option)"),
        USGSLithologySymbol(code: 683, label: "Till or diamicton (3rd option)"),
        USGSLithologySymbol(code: 684, label: "Loess (1st option)"),
        USGSLithologySymbol(code: 685, label: "Loess (2nd option)"),
        USGSLithologySymbol(code: 686, label: "Loess (3rd option)"),
        USGSLithologySymbol(code: 701, label: "Metamorphism"),
        USGSLithologySymbol(code: 702, label: "Quartzite"),
        USGSLithologySymbol(code: 703, label: "Slate"),
        USGSLithologySymbol(code: 704, label: "Schistose or gneissoid granite"),
        USGSLithologySymbol(code: 705, label: "Schist"),
        USGSLithologySymbol(code: 706, label: "Contorted schist"),
        USGSLithologySymbol(code: 707, label: "Schist and gneiss"),
        USGSLithologySymbol(code: 708, label: "Gneiss"),
        USGSLithologySymbol(code: 709, label: "Contorted gneiss"),
        USGSLithologySymbol(code: 710, label: "Soapstone, talc, or serpentinite"),
        USGSLithologySymbol(code: 711, label: "Tuffaceous rock"),
        USGSLithologySymbol(code: 712, label: "Crystal tuff"),
        USGSLithologySymbol(code: 713, label: "Devitrified tuff"),
        USGSLithologySymbol(code: 714, label: "Volcanic breccia and tuff"),
        USGSLithologySymbol(code: 715, label: "Volcanic breccia or agglomerate"),
        USGSLithologySymbol(code: 716, label: "Zeolitic rock"),
        USGSLithologySymbol(code: 717, label: "Basaltic flows"),
        USGSLithologySymbol(code: 718, label: "Granite (1st option)"),
        USGSLithologySymbol(code: 719, label: "Granite (2nd option)"),
        USGSLithologySymbol(code: 720, label: "Banded igneous rock"),
        USGSLithologySymbol(code: 721, label: "Igneous rock (1st option)"),
        USGSLithologySymbol(code: 722, label: "Igneous rock (2nd option)"),
        USGSLithologySymbol(code: 723, label: "Igneous rock (3rd option)"),
        USGSLithologySymbol(code: 724, label: "Igneous rock (4th option)"),
        USGSLithologySymbol(code: 725, label: "Igneous rock (5th option)"),
        USGSLithologySymbol(code: 726, label: "Igneous rock (6th option)"),
        USGSLithologySymbol(code: 727, label: "Igneous rock (7th option)"),
        USGSLithologySymbol(code: 728, label: "Igneous rock (8th option)"),
        USGSLithologySymbol(code: 729, label: "Porphyritic rock (1st option)"),
        USGSLithologySymbol(code: 730, label: "Porphyritic rock (2nd option)"),
        USGSLithologySymbol(code: 731, label: "Vitrophyre"),
        USGSLithologySymbol(code: 732, label: "Quartz"),
        USGSLithologySymbol(code: 733, label: "Ore")
    ]

    public static let fgdcSection37Lithologies: [String] = [
        "Gravel or conglomerate (1st option)",
        "Gravel or conglomerate (2nd option)",
        "Crossbedded gravel or conglomerate",
        "Breccia (1st option)",
        "Breccia (2nd option)",
        "Massive sand or sandstone",
        "Bedded sand or sandstone",
        "Crossbedded sand or sandstone (1st option)",
        "Crossbedded sand or sandstone (2nd option)",
        "Ripple-bedded sand or sandstone",
        "Argillaceous or shaly sandstone",
        "Calcareous sandstone",
        "Dolomitic sandstone",
        "Silt, siltstone, or shaly silt",
        "Calcareous siltstone",
        "Dolomitic siltstone",
        "Sandy or silty shale",
        "Clay or clay shale",
        "Cherty shale",
        "Dolomitic shale",
        "Calcareous shale or marl",
        "Carbonaceous shale",
        "Oil shale",
        "Chalk",
        "Limestone",
        "Clastic limestone",
        "Fossiliferous clastic limestone",
        "Nodular or irregularly bedded limestone",
        "Limestone, irregular (burrow?) fillings of saccharoidal dolomite",
        "Crossbedded limestone",
        "Cherty crossbedded limestone",
        "Cherty and sandy crossbedded clastic limestone",
        "Oolitic limestone",
        "Sandy limestone",
        "Silty limestone",
        "Argillaceous or shaly limestone",
        "Cherty limestone (1st option)",
        "Cherty limestone (2nd option)",
        "Dolomitic limestone, limy dolostone, or limy dolomite",
        "Dolostone or dolomite",
        "Crossbedded dolostone or dolomite",
        "Oolitic dolostone or dolomite",
        "Sandy dolostone or dolomite",
        "Silty dolostone or dolomite",
        "Argillaceous or shaly dolostone or dolomite",
        "Cherty dolostone or dolomite",
        "Bedded chert (1st option)",
        "Bedded chert (2nd option)",
        "Fossiliferous bedded chert",
        "Fossiliferous rock",
        "Diatomaceous rock",
        "Subgraywacke",
        "Crossbedded subgraywacke",
        "Ripple-bedded subgraywacke",
        "Peat",
        "Coal",
        "Bony coal or impure coal",
        "Underclay",
        "Flint clay",
        "Bentonite",
        "Glauconite",
        "Limonite",
        "Siderite",
        "Phosphatic-nodular rock",
        "Gypsum",
        "Salt",
        "Interbedded sandstone and siltstone",
        "Interbedded sandstone and shale",
        "Interbedded ripple-bedded sandstone and shale",
        "Interbedded shale and silty limestone (shale dominant)",
        "Interbedded shale and limestone (shale dominant) (1st option)",
        "Interbedded shale and limestone (shale dominant) (2nd option)",
        "Interbedded calcareous shale and limestone (shale dominant)",
        "Interbedded silty limestone and shale",
        "Interbedded limestone and shale (1st option)",
        "Interbedded limestone and shale (2nd option)",
        "Interbedded limestone and shale (limestone dominant)",
        "Interbedded limestone and calcareous shale",
        "Till or diamicton (1st option)",
        "Till or diamicton (2nd option)",
        "Till or diamicton (3rd option)",
        "Loess (1st option)",
        "Loess (2nd option)",
        "Loess (3rd option)",
        "Metamorphism",
        "Quartzite",
        "Slate",
        "Schistose or gneissoid granite",
        "Schist",
        "Contorted schist",
        "Schist and gneiss",
        "Gneiss",
        "Contorted gneiss",
        "Soapstone, talc, or serpentinite",
        "Tuffaceous rock",
        "Crystal tuff",
        "Devitrified tuff",
        "Volcanic breccia and tuff",
        "Volcanic breccia or agglomerate",
        "Zeolitic rock",
        "Basaltic flows",
        "Granite (1st option)",
        "Granite (2nd option)",
        "Banded igneous rock",
        "Igneous rock (1st option)",
        "Igneous rock (2nd option)",
        "Igneous rock (3rd option)",
        "Igneous rock (4th option)",
        "Igneous rock (5th option)",
        "Igneous rock (6th option)",
        "Igneous rock (7th option)",
        "Igneous rock (8th option)",
        "Porphyritic rock (1st option)",
        "Porphyritic rock (2nd option)",
        "Vitrophyre",
        "Quartz",
        "Ore"
    ]

    public static let fallbackStyle = SymbologyStyle(symbol: .fallback, fillHex: "#F2F2F2", strokeHex: "#333333")

    public static var supportedLithologies: [String] {
        fgdcSection37Lithologies
    }

    public static func lithologies(in category: USGSLithologyCategory) -> [String] {
        supportedLithologies.filter { lithologyCategory(forLithology: $0) == category }
    }

    public static func lithologyCategory(forLithology lithology: String) -> USGSLithologyCategory {
        guard let code = usgsSymbolCode(forLithology: lithology) else { return .other }
        switch code {
        case 601...615, 654...656:
            return .coarseClastics
        case 616...625:
            return .fineClastics
        case 626...648, 672...680:
            return .carbonates
        case 649...653:
            return .siliceousBiogenic
        case 657...668:
            return .organicChemical
        case 669...671:
            return .interbedded
        case 681...686:
            return .unconsolidated
        case 701...710:
            return .metamorphic
        case 711...731:
            return .igneousVolcanic
        case 732...733:
            return .mineralization
        default:
            return .other
        }
    }

    public static func usgsSymbolCode(forLithology lithology: String) -> Int? {
        usgsCodeByNormalizedLithology[normalizedLookupKey(lithology)]
    }

    public static func style(forLithology lithology: String) -> SymbologyStyle {
        guard let code = usgsSymbolCode(forLithology: lithology) else {
            return fallbackStyle
        }
        return style(forUSGSCode: code)
    }

    public static func isSupportedLithology(_ lithology: String) -> Bool {
        supportedLithologySet.contains(normalizedLookupKey(lithology))
    }

    private static let fillByPattern: [SymbolPattern: String] = [
        .sandstone: "#F0D7A3",
        .mudstone: "#C8B39D",
        .shale: "#8A8F99",
        .limestone: "#D9E7C2",
        .dolostone: "#CCE0C2",
        .conglomerate: "#D1B391",
        .siltstone: "#CABDAB",
        .claystone: "#AF9E8F",
        .marl: "#C7D8B4",
        .chert: "#BFD6E1",
        .coal: "#5A5A5A",
        .evaporite: "#E7E7F0",
        .fallback: "#F2F2F2"
    ]

    private static let usgsCodeByNormalizedLithology: [String: Int] = Dictionary(
        uniqueKeysWithValues: usgsSection37OfficialSymbols.map { symbol in
            (normalizedLookupKey(symbol.label), symbol.code)
        }
    )

    private static let supportedLithologySet: Set<String> = Set(fgdcSection37Lithologies.map(normalizedLookupKey))

    private static func style(forUSGSCode code: Int) -> SymbologyStyle {
        let symbol = symbolPattern(forUSGSCode: code)
        let fillHex = fillByPattern[symbol] ?? fallbackStyle.fillHex
        return SymbologyStyle(symbol: symbol, fillHex: fillHex)
    }

    private static func symbolPattern(forUSGSCode code: Int) -> SymbolPattern {
        switch code {
        case 601...606:
            return .conglomerate
        case 607...614, 654...656:
            return .sandstone
        case 616...618:
            return .siltstone
        case 619...622:
            return .shale
        case 623:
            return .marl
        case 624...625:
            return .shale
        case 626...640, 652...653, 672...680:
            return .limestone
        case 641...648:
            return .dolostone
        case 649...651, 732:
            return .chert
        case 657...659:
            return .coal
        case 660...662:
            return .claystone
        case 663...666, 701...731, 733:
            return .fallback
        case 667...668:
            return .evaporite
        case 669...671:
            return .sandstone
        case 681...683:
            return .conglomerate
        case 684...686:
            return .siltstone
        default:
            return .fallback
        }
    }

    private static func normalizedLookupKey(_ lithology: String) -> String {
        String(
            lithology
                .lowercased()
                .unicodeScalars
                .filter { CharacterSet.alphanumerics.contains($0) }
        )
    }
}
