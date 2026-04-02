import SwiftUI

public struct UnitFormView: View {
    @Binding private var unit: StratigraphicUnit
    @State private var thicknessText: String = ""
    @State private var selectedLithologyCategory: USGSLithologyCategory
    @State private var pendingPointFeatureCategory: PointFeatureCategory
    @State private var pendingPointFeatureType: PointFeatureType = PointFeatureType.allCases.first ?? .paleoMacroFossils

    public init(unit: Binding<StratigraphicUnit>) {
        self._unit = unit
        self._thicknessText = State(initialValue: Self.formatNumber(unit.wrappedValue.thickness))
        self._selectedLithologyCategory = State(initialValue: SymbologyLibrary.lithologyCategory(forLithology: unit.wrappedValue.lithology))
        self._pendingPointFeatureCategory = State(initialValue: PointFeatureType.allCases.first?.category ?? .biological)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Unit Details")
                .font(.headline)
            TextField("Name", text: $unit.name)
            TextField("Thickness (m)", text: thicknessBinding)
            Picker("Lithology Group", selection: $selectedLithologyCategory) {
                ForEach(availableLithologyCategories, id: \.self) { category in
                    Text(category.label).tag(category)
                }
            }
            .onChange(of: selectedLithologyCategory) { _ in
                normalizeLithologySelection()
            }
            Picker("Lithology", selection: $unit.lithology) {
                ForEach(lithologiesInSelectedCategory, id: \.self) { lithology in
                    Text(lithology).tag(lithology)
                }
            }
            if let usgsCode = SymbologyLibrary.usgsSymbolCode(forLithology: unit.lithology) {
                Text("USGS Symbol \(usgsCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Grain Size", selection: grainSizeBinding) {
                Text("Unset").tag(nil as USGSGrainSize?)
                ForEach(USGSGrainSize.allCases, id: \.self) { size in
                    Text(size.label).tag(Optional(size))
                }
            }

            Divider()
            Text("Point Features")
                .font(.headline)

            if unit.pointFeatures.isEmpty {
                Text("No point features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(unit.pointFeatures.indices), id: \.self) { index in
                    pointFeatureRow(index: index)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                Picker("Category", selection: $pendingPointFeatureCategory) {
                    ForEach(availablePointFeatureCategories, id: \.self) { category in
                        Text(category.label).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .disabled(availablePointFeaturesToAdd.isEmpty)
                .onChange(of: pendingPointFeatureCategory) { _ in
                    normalizePendingFeatureSelection()
                }

                Picker("Feature Type", selection: $pendingPointFeatureType) {
                    ForEach(availablePointFeaturesInSelectedCategory, id: \.self) { featureType in
                        Text(featureType.label).tag(featureType)
                    }
                }
                .pickerStyle(.menu)
                .disabled(availablePointFeaturesToAdd.isEmpty)

                Button("Add") {
                    addPendingPointFeature()
                }
                .disabled(availablePointFeaturesToAdd.isEmpty)
            }
        }
        .onAppear {
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            syncLithologyCategoryWithUnit()
            normalizeLithologySelection()
            normalizePendingFeatureSelection()
        }
        .onChange(of: unit.id) { _ in
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            syncLithologyCategoryWithUnit()
            normalizeLithologySelection()
            normalizePendingFeatureSelection()
        }
    }

    private var availableLithologyCategories: [USGSLithologyCategory] {
        USGSLithologyCategory.allCases.filter { !SymbologyLibrary.lithologies(in: $0).isEmpty }
    }

    private var lithologiesInSelectedCategory: [String] {
        SymbologyLibrary.lithologies(in: selectedLithologyCategory)
    }

    private func syncLithologyCategoryWithUnit() {
        selectedLithologyCategory = SymbologyLibrary.lithologyCategory(forLithology: unit.lithology)
        if !availableLithologyCategories.contains(selectedLithologyCategory) {
            selectedLithologyCategory = availableLithologyCategories.first ?? .coarseClastics
        }
    }

    private func normalizeLithologySelection() {
        guard !availableLithologyCategories.isEmpty else { return }
        if !availableLithologyCategories.contains(selectedLithologyCategory) {
            selectedLithologyCategory = availableLithologyCategories[0]
        }
        let choices = lithologiesInSelectedCategory
        guard let first = choices.first else { return }
        if !choices.contains(unit.lithology) {
            unit.lithology = first
        }
    }

    private func coerceLithologyToSupportedValueIfNeeded() {
        guard !SymbologyLibrary.isSupportedLithology(unit.lithology) else { return }
        unit.lithology = SymbologyLibrary.supportedLithologies.first ?? unit.lithology
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
                ForEach(PointFeatureCategory.allCases, id: \.self) { category in
                    let types = PointFeatureType.allCases.filter { $0.category == category }
                    if !types.isEmpty {
                        Section(category.label) {
                            ForEach(types, id: \.self) { featureType in
                                Text(featureType.label)
                                    .tag(featureType)
                            }
                        }
                    }
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

            Button("Delete") {
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

    private var availablePointFeatureCategories: [PointFeatureCategory] {
        PointFeatureCategory.allCases.filter { category in
            availablePointFeaturesToAdd.contains { $0.category == category }
        }
    }

    private var availablePointFeaturesInSelectedCategory: [PointFeatureType] {
        availablePointFeaturesToAdd.filter { $0.category == pendingPointFeatureCategory }
    }

    private func normalizePendingFeatureSelection() {
        let available = availablePointFeaturesToAdd
        guard let firstAvailable = available.first else { return }

        if !availablePointFeatureCategories.contains(pendingPointFeatureCategory) {
            pendingPointFeatureCategory = firstAvailable.category
        }

        let categoryOptions = availablePointFeaturesInSelectedCategory
        if !categoryOptions.contains(pendingPointFeatureType) {
            pendingPointFeatureType = categoryOptions.first ?? firstAvailable
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
