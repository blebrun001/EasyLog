import Foundation

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

public enum SymbologyLibrary {
    public static let coreLithologies: [String: SymbologyStyle] = [
        "sandstone": SymbologyStyle(symbol: .sandstone, fillHex: "#F0D7A3"),
        "mudstone": SymbologyStyle(symbol: .mudstone, fillHex: "#C8B39D"),
        "shale": SymbologyStyle(symbol: .shale, fillHex: "#8A8F99"),
        "limestone": SymbologyStyle(symbol: .limestone, fillHex: "#D9E7C2"),
        "dolostone": SymbologyStyle(symbol: .dolostone, fillHex: "#CCE0C2"),
        "conglomerate": SymbologyStyle(symbol: .conglomerate, fillHex: "#D1B391"),
        "siltstone": SymbologyStyle(symbol: .siltstone, fillHex: "#CABDAB"),
        "claystone": SymbologyStyle(symbol: .claystone, fillHex: "#AF9E8F"),
        "marl": SymbologyStyle(symbol: .marl, fillHex: "#C7D8B4"),
        "chert": SymbologyStyle(symbol: .chert, fillHex: "#BFD6E1"),
        "coal": SymbologyStyle(symbol: .coal, fillHex: "#5A5A5A"),
        "evaporite": SymbologyStyle(symbol: .evaporite, fillHex: "#E7E7F0")
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

    public static func style(forLithology lithology: String) -> SymbologyStyle {
        let key = normalizedLithology(lithology)
        if let style = coreLithologies[key] {
            return style
        }

        if key.contains("sandstone") || key.contains("subgraywacke") {
            return coreLithologies["sandstone"] ?? fallbackStyle
        }
        if key.contains("mudstone") {
            return coreLithologies["mudstone"] ?? fallbackStyle
        }
        if key.contains("shale") || key.contains("slate") {
            return coreLithologies["shale"] ?? fallbackStyle
        }
        if key.contains("limestone") || key.contains("chalk") {
            return coreLithologies["limestone"] ?? fallbackStyle
        }
        if key.contains("dolostone") || key.contains("dolomite") {
            return coreLithologies["dolostone"] ?? fallbackStyle
        }
        if key.contains("conglomerate") || key.contains("gravel") || key.contains("breccia") || key.contains("till") || key.contains("diamicton") {
            return coreLithologies["conglomerate"] ?? fallbackStyle
        }
        if key.contains("siltstone") || key.contains(" silt") {
            return coreLithologies["siltstone"] ?? fallbackStyle
        }
        if key.contains("clay") || key.contains("bentonite") {
            return coreLithologies["claystone"] ?? fallbackStyle
        }
        if key.contains("marl") {
            return coreLithologies["marl"] ?? fallbackStyle
        }
        if key.contains("chert") || key.contains("quartz") {
            return coreLithologies["chert"] ?? fallbackStyle
        }
        if key.contains("coal") || key.contains("peat") {
            return coreLithologies["coal"] ?? fallbackStyle
        }
        if key.contains("gypsum") || key.contains("salt") {
            return coreLithologies["evaporite"] ?? fallbackStyle
        }

        return coreLithologies[key] ?? fallbackStyle
    }

    public static func isSupportedLithology(_ lithology: String) -> Bool {
        supportedLithologySet.contains(normalizedLithology(lithology))
    }

    private static let supportedLithologySet: Set<String> = Set(fgdcSection37Lithologies.map(normalizedLithology))

    private static func normalizedLithology(_ lithology: String) -> String {
        lithology.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
