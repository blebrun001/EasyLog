import SwiftUI

/// Form that edits one `StratigraphicUnit`, including lithology and point features.
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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Unit Details")

                fieldGroup("Name") {
                    TextField("Name", text: $unit.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Unit name")
                }

                fieldGroup("Thickness (m)") {
                    TextField("Thickness (m)", text: thicknessBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Thickness in meters")
                }

                fieldGroup("Lithology Group") {
                    Picker("Lithology Group", selection: $selectedLithologyCategory) {
                        ForEach(availableLithologyCategories, id: \.self) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Lithology Group")
                    .onChange(of: selectedLithologyCategory) { _ in
                        normalizeLithologySelection()
                    }
                }

                fieldGroup("Lithology") {
                    Picker("Lithology", selection: $unit.lithology) {
                        ForEach(lithologiesInSelectedCategory, id: \.self) { lithology in
                            Text(lithology).tag(lithology)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Lithology")
                }

                fieldGroup("Grain Size") {
                    Picker("Grain Size", selection: grainSizeBinding) {
                        Text("Unset").tag(nil as USGSGrainSize?)
                        ForEach(USGSGrainSize.allCases, id: \.self) { size in
                            Text(size.label).tag(Optional(size))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Grain Size")
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Point Features")
                    Spacer()
                    Text("\(unit.pointFeatures.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary.opacity(0.6), in: Capsule())
                        .foregroundStyle(.secondary)
                }

                if !unit.pointFeatures.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(unit.pointFeatures.indices), id: \.self) { index in
                            pointFeatureRow(index: index)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Add Feature")
                        .font(.subheadline.weight(.semibold))

                    fieldGroup("Category") {
                        Picker("Category", selection: $pendingPointFeatureCategory) {
                            ForEach(availablePointFeatureCategories, id: \.self) { category in
                                Text(category.label).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Point feature category")
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .onChange(of: pendingPointFeatureCategory) { _ in
                            normalizePendingFeatureSelection()
                        }
                    }

                    fieldGroup("Feature Type") {
                        Picker("Feature Type", selection: $pendingPointFeatureType) {
                            ForEach(availablePointFeaturesInSelectedCategory, id: \.self) { featureType in
                                Text(featureType.label).tag(featureType)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Point feature type")
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                    }

                    HStack {
                        Spacer()
                        Button {
                            addPendingPointFeature()
                        } label: {
                            Label("Add Feature", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .accessibilityHint("Adds the selected point feature to this unit")
                    }
                }
                .padding(10)
                .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(12)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(unit.pointFeatures[index].type.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Picker("Feature Type", selection: $unit.pointFeatures[index].type) {
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
                .labelsHidden()
                .frame(maxWidth: 120, alignment: .trailing)
                .accessibilityLabel("Feature Type")

                Button {
                    unit.pointFeatures.remove(at: index)
                    normalizePendingFeatureSelection()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .accessibilityLabel("Delete feature")
                .accessibilityHint("Removes this point feature from the unit")
            }

            HStack(spacing: 8) {
                Text("Density")
                    .font(.subheadline)
                    .frame(width: 58, alignment: .leading)
                Slider(value: densityBinding(for: index), in: 0...1, step: 0.05)
                    .accessibilityLabel("Feature density")
                Text("\(Int((unit.pointFeatures[index].density * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .padding(8)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func densityBinding(for index: Int) -> Binding<Double> {
        Binding<Double>(
            get: { unit.pointFeatures[index].density },
            set: { unit.pointFeatures[index].density = min(max($0, 0), 1) }
        )
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            UnitPointFeature(type: pendingPointFeatureType, density: 0.35)
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
