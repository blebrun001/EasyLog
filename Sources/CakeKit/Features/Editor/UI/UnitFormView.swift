import SwiftUI

public struct UnitFormView: View {
    @Binding private var unit: StratigraphicUnit
    @State private var thicknessText: String = ""

    public init(unit: Binding<StratigraphicUnit>) {
        self._unit = unit
        self._thicknessText = State(initialValue: Self.formatNumber(unit.wrappedValue.thickness))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unit Details")
                .font(.headline)
            TextField("Name", text: $unit.name)
            TextField("Thickness (m)", text: thicknessBinding)
            Picker("Lithology", selection: $unit.lithology) {
                ForEach(availableLithologies, id: \.self) { lithology in
                    Text(lithology).tag(lithology)
                }
            }
            Picker("Grain size", selection: grainSizeBinding) {
                Text("Unset").tag(nil as USGSGrainSize?)
                ForEach(USGSGrainSize.allCases, id: \.self) { size in
                    Text(size.label).tag(Optional(size))
                }
            }
        }
        .onAppear {
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
        }
        .onChange(of: unit.id) { _ in
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
        }
    }

    private var availableLithologies: [String] {
        SymbologyLibrary.supportedLithologies
    }

    private func coerceLithologyToSupportedValueIfNeeded() {
        guard !SymbologyLibrary.isSupportedLithology(unit.lithology) else { return }
        unit.lithology = availableLithologies.first ?? unit.lithology
    }

    private var grainSizeBinding: Binding<USGSGrainSize?> {
        Binding<USGSGrainSize?>(
            get: { unit.grainSize },
            set: { unit.grainSize = $0 }
        )
    }

    private var thicknessBinding: Binding<String> {
        Binding(
            get: { thicknessText },
            set: { raw in
                thicknessText = raw
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                if let parsed = parseNumber(trimmed) {
                    unit.thickness = parsed
                }
            }
        )
    }

    private func parseNumber(_ raw: String) -> Double? {
        if let value = Self.numberFormatter.number(from: raw)?.doubleValue {
            return value
        }
        return Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    private static func formatNumber(_ value: Double) -> String {
        Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()
}
