import SwiftUI
import AppKit

/// Form that edits one `StratigraphicUnit`, including lithology and point features.
public struct UnitFormView: View {
    @Binding private var unit: StratigraphicUnit
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var thicknessText: String = ""
    @State private var selectedLithologyCategory: USGSLithologyCategory
    @State private var selectedLithologyCode: Int
    @State private var showLithologyColorChangeDialog = false
    @State private var showColorProfilesSheet = false
    @State private var pendingLithologySelectionCode: Int?
    @State private var colorPickerSelection: Color = .clear
    @State private var lithologyHexText: String = ""
    @State private var pendingPointFeatureCategory: PointFeatureCategory
    @State private var pendingPointFeatureType: PointFeatureType = PointFeatureType.allCases.first ?? .paleoMacroFossils

    public init(unit: Binding<StratigraphicUnit>, viewModel: ProjectViewModel) {
        self._unit = unit
        self.viewModel = viewModel
        self._thicknessText = State(initialValue: Self.formatNumber(unit.wrappedValue.thickness))
        self._selectedLithologyCategory = State(initialValue: SymbologyLibrary.lithologyCategory(forUSGSCode: unit.wrappedValue.usgsLithologyCode))
        self._selectedLithologyCode = State(initialValue: unit.wrappedValue.usgsLithologyCode)
        self._pendingPointFeatureCategory = State(initialValue: PointFeatureType.allCases.first?.category ?? .biological)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProPanelSection("Unit Details", subtitle: "Core stratigraphic attributes") {

                fieldGroup("Name") {
                    TextField("", text: $unit.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Unit name")
                }

                fieldGroup("Thickness (m)") {
                    TextField("", text: thicknessBinding)
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
                    .onChange(of: selectedLithologyCategory) { _, _ in
                        normalizeLithologySelection()
                    }
                }

                fieldGroup("Lithology") {
                    Picker("Lithology", selection: lithologyBinding) {
                        ForEach(lithologySymbolsInSelectedCategory, id: \.code) { symbol in
                            Text("\(symbol.label) (\(symbol.code))").tag(symbol.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Lithology")
                }
                if let aliased = SymbologyLibrary.usgsLithologyAliases[unit.usgsLithologyCode] {
                    Text("Code \(unit.usgsLithologyCode) uses rendered swatch \(aliased).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                fieldGroup("Lithology Color") {
                    VStack(alignment: .leading, spacing: 8) {
                        ColorPicker("Custom Color", selection: lithologyColorBinding, supportsOpacity: false)
                            .accessibilityLabel("Lithology custom color")

                        HStack(spacing: 8) {
                            TextField("#RRGGBB", text: lithologyHexBinding)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .accessibilityLabel("Lithology color hex")

                            Button("Reset to USGS") {
                                unit.lithologyColorHex = nil
                                syncColorControlsFromUnit()
                            }
                            .buttonStyle(.bordered)
                            .disabled(unit.lithologyColorHex == nil)
                            .accessibilityHint("Removes custom color and restores default USGS color")
                        }

                        HStack(spacing: 8) {
                            Button("Apply Profile Color") {
                                viewModel.applyPresetToSelectedUnit()
                                syncColorControlsFromUnit()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.presetColor(for: unit.usgsLithologyCode) == nil)

                            Button("Color Profiles…") {
                                showColorProfilesSheet = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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

            ProPanelSection("Point Features", subtitle: "Additional symbols and density") {
                ProBadge("\(unit.pointFeatures.count)")
            } content: {

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
                        .onChange(of: pendingPointFeatureCategory) { _, _ in
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
                        .buttonStyle(.bordered)
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .accessibilityHint("Adds the selected point feature to this unit")
                    }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .onAppear {
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            syncLithologyCategoryWithUnit()
            normalizeLithologySelection()
            syncColorControlsFromUnit()
            normalizePendingFeatureSelection()
        }
        .onChange(of: unit.id) { _, _ in
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            syncLithologyCategoryWithUnit()
            normalizeLithologySelection()
            syncColorControlsFromUnit()
            normalizePendingFeatureSelection()
        }
        .confirmationDialog(
            "Keep custom color?",
            isPresented: $showLithologyColorChangeDialog,
            titleVisibility: .visible
        ) {
            Button("Keep custom color") {
                applyPendingLithologySelection(resetColor: false)
            }
            Button("Reset to USGS color", role: .destructive) {
                applyPendingLithologySelection(resetColor: true)
            }
            Button("Cancel", role: .cancel) {
                pendingLithologySelectionCode = nil
                selectedLithologyCode = unit.usgsLithologyCode
            }
        } message: {
            Text("Changing lithology while a custom color is set can either keep your custom color or restore the default USGS fill.")
        }
        .sheet(isPresented: $showColorProfilesSheet) {
            LithologyColorProfilesSheetView(viewModel: viewModel)
                .frame(minWidth: 760, minHeight: 620)
        }
    }

    private var availableLithologyCategories: [USGSLithologyCategory] {
        USGSLithologyCategory.allCases.filter { !SymbologyLibrary.symbols(in: $0).isEmpty }
    }

    private var lithologySymbolsInSelectedCategory: [USGSLithologySymbol] {
        SymbologyLibrary.symbols(in: selectedLithologyCategory)
    }

    private func syncLithologyCategoryWithUnit() {
        selectedLithologyCode = unit.usgsLithologyCode
        selectedLithologyCategory = SymbologyLibrary.lithologyCategory(forUSGSCode: unit.usgsLithologyCode)
        if !availableLithologyCategories.contains(selectedLithologyCategory) {
            selectedLithologyCategory = availableLithologyCategories.first ?? .coarseClastics
        }
    }

    private func normalizeLithologySelection() {
        guard !availableLithologyCategories.isEmpty else { return }
        if !availableLithologyCategories.contains(selectedLithologyCategory) {
            selectedLithologyCategory = availableLithologyCategories[0]
        }
        let choices = lithologySymbolsInSelectedCategory.map(\.code)
        guard let first = choices.first else { return }
        if !choices.contains(selectedLithologyCode) {
            selectedLithologyCode = first
        }
        if !choices.contains(unit.usgsLithologyCode) {
            requestLithologyChange(to: selectedLithologyCode)
        }
    }

    private func coerceLithologyToSupportedValueIfNeeded() {
        guard !SymbologyLibrary.isSupportedUSGSLithologyCode(unit.usgsLithologyCode) else { return }
        unit.usgsLithologyCode = SymbologyLibrary.supportedUSGSCodes.first ?? unit.usgsLithologyCode
        selectedLithologyCode = unit.usgsLithologyCode
    }

    private var lithologyBinding: Binding<Int> {
        Binding(
            get: { selectedLithologyCode },
            set: { candidate in
                guard candidate != selectedLithologyCode else { return }
                requestLithologyChange(to: candidate)
            }
        )
    }

    private var lithologyColorBinding: Binding<Color> {
        Binding(
            get: { colorPickerSelection },
            set: { newColor in
                colorPickerSelection = newColor
                let nsColor = NSColor(newColor)
                guard let hex = ColorHex.hex(from: nsColor) else { return }
                unit.lithologyColorHex = hex
                lithologyHexText = hex
            }
        )
    }

    private var lithologyHexBinding: Binding<String> {
        Binding(
            get: { lithologyHexText },
            set: { raw in
                lithologyHexText = raw
                guard let normalized = ColorHex.normalizedHex(raw) else { return }
                unit.lithologyColorHex = normalized
                if let nsColor = ColorHex.nsColor(from: normalized) {
                    colorPickerSelection = Color(nsColor: nsColor)
                }
                lithologyHexText = normalized
            }
        )
    }

    private func applyPendingLithologySelection(resetColor: Bool) {
        guard let pending = pendingLithologySelectionCode else { return }
        pendingLithologySelectionCode = nil
        unit.usgsLithologyCode = pending
        selectedLithologyCode = pending
        if resetColor {
            unit.lithologyColorHex = nil
        }
        syncColorControlsFromUnit()
    }

    private func requestLithologyChange(to candidate: Int) {
        guard candidate != unit.usgsLithologyCode else {
            selectedLithologyCode = unit.usgsLithologyCode
            return
        }
        if unit.lithologyColorHex != nil {
            pendingLithologySelectionCode = candidate
            showLithologyColorChangeDialog = true
            selectedLithologyCode = unit.usgsLithologyCode
            return
        }

        unit.usgsLithologyCode = candidate
        selectedLithologyCode = candidate
        syncColorControlsFromUnit()
    }

    private func syncColorControlsFromUnit() {
        selectedLithologyCode = unit.usgsLithologyCode
        if let custom = ColorHex.normalizedHex(unit.lithologyColorHex),
           let nsColor = ColorHex.nsColor(from: custom) {
            unit.lithologyColorHex = custom
            colorPickerSelection = Color(nsColor: nsColor)
            lithologyHexText = custom
            return
        }

        unit.lithologyColorHex = nil
        let fallbackHex = SymbologyLibrary.style(forUSGSCode: unit.usgsLithologyCode).fillHex
        if let fallbackColor = ColorHex.nsColor(from: fallbackHex) {
            colorPickerSelection = Color(nsColor: fallbackColor)
        } else {
            colorPickerSelection = .clear
        }
        lithologyHexText = ""
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
                Slider(value: densityBinding(for: index), in: 0...1)
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
            set: { unit.pointFeatures[index].density = snapped($0, step: 0.05, range: 0...1) }
        )
    }

    private func snapped(_ value: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        ProField(label) {
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
