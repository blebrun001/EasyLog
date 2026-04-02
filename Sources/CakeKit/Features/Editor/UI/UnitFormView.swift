import SwiftUI

public struct UnitFormView: View {
    @Binding private var unit: StratigraphicUnit
    @State private var thicknessText: String = ""
    @State private var pendingPointFeatureType: PointFeatureType = PointFeatureType.allCases.first ?? .paleoMacroFossils

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
            if let usgsCode = SymbologyLibrary.usgsSymbolCode(forLithology: unit.lithology) {
                Text("USGS symbol \(usgsCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Grain size", selection: grainSizeBinding) {
                Text("Unset").tag(nil as USGSGrainSize?)
                ForEach(USGSGrainSize.allCases, id: \.self) { size in
                    Text(size.label).tag(Optional(size))
                }
            }

            Divider()
            Text("Elements ponctuels")
                .font(.headline)

            if unit.pointFeatures.isEmpty {
                Text("Aucun element ponctuel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(unit.pointFeatures.indices), id: \.self) { index in
                    pointFeatureRow(index: index)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Picker("Ajouter", selection: $pendingPointFeatureType) {
                    ForEach(availablePointFeaturesToAdd, id: \.self) { featureType in
                        Text("\(featureType.categoryLabel): \(featureType.label)")
                            .tag(featureType)
                    }
                }
                .pickerStyle(.menu)
                .disabled(availablePointFeaturesToAdd.isEmpty)

                Button("Ajouter") {
                    addPendingPointFeature()
                }
                .disabled(availablePointFeaturesToAdd.isEmpty)
            }
        }
        .onAppear {
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            normalizePendingFeatureSelection()
        }
        .onChange(of: unit.id) { _ in
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            normalizePendingFeatureSelection()
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

    @ViewBuilder
    private func pointFeatureRow(index: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Picker("Type", selection: $unit.pointFeatures[index].type) {
                ForEach(PointFeatureType.allCases, id: \.self) { featureType in
                    Text("\(featureType.categoryLabel): \(featureType.label)")
                        .tag(featureType)
                }
            }
            .pickerStyle(.menu)

            Picker("Concentration", selection: $unit.pointFeatures[index].concentration) {
                ForEach(PointFeatureConcentration.allCases, id: \.self) { concentration in
                    Text(concentration.label).tag(concentration)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 210)

            Button("Suppr.") {
                unit.pointFeatures.remove(at: index)
                normalizePendingFeatureSelection()
            }
            .buttonStyle(.borderless)
        }
    }

    private var availablePointFeaturesToAdd: [PointFeatureType] {
        let used = Set(unit.pointFeatures.map(\.type))
        return PointFeatureType.allCases.filter { !used.contains($0) }
    }

    private func normalizePendingFeatureSelection() {
        guard let firstAvailable = availablePointFeaturesToAdd.first else { return }
        if !availablePointFeaturesToAdd.contains(pendingPointFeatureType) {
            pendingPointFeatureType = firstAvailable
        }
    }

    private func addPendingPointFeature() {
        guard availablePointFeaturesToAdd.contains(pendingPointFeatureType) else { return }
        unit.pointFeatures.append(
            UnitPointFeature(type: pendingPointFeatureType, concentration: .low)
        )
        normalizePendingFeatureSelection()
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
