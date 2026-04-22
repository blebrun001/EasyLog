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
    @State private var pointFeatureHexTextByID: [UUID: String] = [:]
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
            ProPanelSection(l10n("Unit Details"), subtitle: l10n("Core stratigraphic attributes")) {

                fieldGroup(l10n("Name")) {
                    TextField("", text: $unit.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(l10n("Unit name"))
                        .help(l10n("Enter the unit name"))
                }

                fieldGroup(l10n("Thickness (m)")) {
                    TextField("", text: thicknessBinding)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(l10n("Thickness in meters"))
                        .help(l10n("Enter unit thickness in meters"))
                }

                fieldGroup(l10n("Lithology Group")) {
                    Picker(l10n("Lithology Group"), selection: $selectedLithologyCategory) {
                        ForEach(availableLithologyCategories, id: \.self) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(l10n("Lithology Group"))
                    .help(l10n("Choose a lithology category"))
                    .onChange(of: selectedLithologyCategory) { _, _ in
                        normalizeLithologySelection()
                    }
                }

                fieldGroup(l10n("Lithology")) {
                    Picker(l10n("Lithology"), selection: lithologyBinding) {
                        ForEach(lithologySymbolsInSelectedCategory, id: \.code) { symbol in
                            Text("\(symbol.label) (\(symbol.code))").tag(symbol.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(l10n("Lithology"))
                    .help(l10n("Choose a lithology for this unit"))
                }
                if let aliased = SymbologyLibrary.usgsLithologyAliases[unit.usgsLithologyCode] {
                    Text("Code \(unit.usgsLithologyCode) uses rendered swatch \(aliased).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                fieldGroup(l10n("Lithology Color")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ColorPicker(l10n("Custom Color"), selection: lithologyColorBinding, supportsOpacity: false)
                            .accessibilityLabel(l10n("Lithology custom color"))
                            .help(l10n("Pick a custom lithology color"))

                        HStack(spacing: 8) {
                            TextField("#RRGGBB", text: lithologyHexBinding)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .accessibilityLabel(l10n("Lithology color hex"))
                                .help(l10n("Enter a custom lithology color in hex format"))

                            Button(l10n("Reset to USGS")) {
                                unit.lithologyColorHex = nil
                                syncColorControlsFromUnit()
                            }
                            .buttonStyle(.bordered)
                            .disabled(unit.lithologyColorHex == nil)
                            .accessibilityHint(l10n("Removes custom color and restores default USGS color"))
                            .help(l10n("Reset to the default USGS lithology color"))
                        }

                        HStack(spacing: 8) {
                            Button(l10n("Apply Profile Color")) {
                                viewModel.applyPresetToSelectedUnit()
                                syncColorControlsFromUnit()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.presetColor(for: unit.usgsLithologyCode) == nil)
                            .help(l10n("Apply the active profile color to this unit"))

                            Button(l10n("Color Profiles…")) {
                                showColorProfilesSheet = true
                            }
                            .buttonStyle(.bordered)
                            .help(l10n("Open lithology color profiles"))
                        }
                    }
                }

                fieldGroup(l10n("Grain Size")) {
                    Picker(l10n("Grain Size"), selection: grainSizeBinding) {
                        Text(l10n("Unset")).tag(nil as USGSGrainSize?)
                        ForEach(USGSGrainSize.allCases, id: \.self) { size in
                            Text(size.label).tag(Optional(size))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(l10n("Grain Size"))
                    .help(l10n("Choose grain size for this unit"))
                }
            }

            ProPanelSection(l10n("Point Features"), subtitle: l10n("Additional symbols and density")) {
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
                        Text(l10n("Add Feature"))
                            .font(.subheadline.weight(.semibold))

                    fieldGroup(l10n("Category")) {
                        Picker(l10n("Category"), selection: $pendingPointFeatureCategory) {
                            ForEach(availablePointFeatureCategories, id: \.self) { category in
                                Text(category.label).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(l10n("Point feature category"))
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .help(l10n("Choose a point feature category to add"))
                        .onChange(of: pendingPointFeatureCategory) { _, _ in
                            normalizePendingFeatureSelection()
                        }
                    }

                    fieldGroup(l10n("Feature Type")) {
                        Picker(l10n("Feature Type"), selection: $pendingPointFeatureType) {
                            ForEach(availablePointFeaturesInSelectedCategory, id: \.self) { featureType in
                                Text(featureType.label).tag(featureType)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(l10n("Point feature type"))
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .help(l10n("Choose a point feature type to add"))
                    }

                    HStack {
                        Spacer()
                        Button {
                            addPendingPointFeature()
                        } label: {
                            Label(l10n("Add Feature"), systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(availablePointFeaturesToAdd.isEmpty)
                        .accessibilityHint(l10n("Adds the selected point feature to this unit"))
                        .help(l10n("Add the selected point feature"))
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
            syncPointFeatureColorControls()
            normalizePendingFeatureSelection()
        }
        .onChange(of: unit.id) { _, _ in
            coerceLithologyToSupportedValueIfNeeded()
            thicknessText = Self.formatNumber(unit.thickness)
            syncLithologyCategoryWithUnit()
            normalizeLithologySelection()
            syncColorControlsFromUnit()
            syncPointFeatureColorControls()
            normalizePendingFeatureSelection()
        }
        .confirmationDialog(
            l10n("Keep custom color?"),
            isPresented: $showLithologyColorChangeDialog,
            titleVisibility: .visible
        ) {
            Button(l10n("Keep custom color")) {
                applyPendingLithologySelection(resetColor: false)
            }
            Button(l10n("Reset to USGS color"), role: .destructive) {
                applyPendingLithologySelection(resetColor: true)
            }
            Button(l10n("Cancel"), role: .cancel) {
                pendingLithologySelectionCode = nil
                selectedLithologyCode = unit.usgsLithologyCode
            }
        } message: {
            Text(
                l10n(
                    "Changing lithology while a custom color is set can either keep your custom color or restore the default USGS fill."
                )
            )
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
                .accessibilityLabel(l10n("Feature Type"))
                .help(l10n("Change this point feature type"))

                Button {
                    unit.pointFeatures.remove(at: index)
                    syncPointFeatureColorControls()
                    normalizePendingFeatureSelection()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .accessibilityLabel(l10n("Delete feature"))
                .accessibilityHint(l10n("Removes this point feature from the unit"))
                .help(l10n("Delete this point feature"))
            }

            HStack(spacing: 8) {
                Text(l10n("Density"))
                    .font(.subheadline)
                    .frame(width: 58, alignment: .leading)
                Slider(value: densityBinding(for: index), in: 0...1)
                    .accessibilityLabel(l10n("Feature density"))
                    .help(l10n("Adjust feature density"))
                Text("\(Int((unit.pointFeatures[index].density * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                ColorPicker(l10n("Icon Color"), selection: pointFeatureColorBinding(for: index), supportsOpacity: false)
                    .accessibilityLabel(l10n("Point feature icon color"))
                    .help(l10n("Pick a custom point feature icon color"))

                HStack(spacing: 8) {
                    TextField("#RRGGBB", text: pointFeatureHexBinding(for: index))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityLabel(l10n("Point feature color hex"))
                        .help(l10n("Enter point feature icon color in hex format"))

                    Button(l10n("Default")) {
                        let featureID = unit.pointFeatures[index].id
                        unit.pointFeatures[index].colorHex = nil
                        pointFeatureHexTextByID[featureID] = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(unit.pointFeatures[index].colorHex == nil)
                    .accessibilityHint(l10n("Resets point feature icon color to the default black"))
                    .help(l10n("Reset to the default point feature icon color"))
                }
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
        syncPointFeatureColorControls()
        normalizePendingFeatureSelection()
    }

    private func syncPointFeatureColorControls() {
        var updated: [UUID: String] = [:]
        for pointFeature in unit.pointFeatures {
            updated[pointFeature.id] = pointFeature.colorHex ?? ""
        }
        pointFeatureHexTextByID = updated
    }

    private func pointFeatureColorBinding(for index: Int) -> Binding<Color> {
        Binding(
            get: {
                let normalized = unit.pointFeatures[index].colorHex ?? UnitPointFeature.defaultColorHex
                if let nsColor = ColorHex.nsColor(from: normalized) {
                    return Color(nsColor: nsColor)
                }
                return .black
            },
            set: { newColor in
                let featureID = unit.pointFeatures[index].id
                let nsColor = NSColor(newColor)
                guard let hex = ColorHex.hex(from: nsColor) else { return }
                unit.pointFeatures[index].colorHex = hex
                pointFeatureHexTextByID[featureID] = hex
            }
        )
    }

    private func pointFeatureHexBinding(for index: Int) -> Binding<String> {
        Binding(
            get: {
                let featureID = unit.pointFeatures[index].id
                return pointFeatureHexTextByID[featureID] ?? unit.pointFeatures[index].colorHex ?? ""
            },
            set: { raw in
                let featureID = unit.pointFeatures[index].id
                pointFeatureHexTextByID[featureID] = raw
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    unit.pointFeatures[index].colorHex = nil
                    pointFeatureHexTextByID[featureID] = ""
                    return
                }
                guard let normalized = ColorHex.normalizedHex(raw) else { return }
                unit.pointFeatures[index].colorHex = normalized
                pointFeatureHexTextByID[featureID] = normalized
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
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private func l10n(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: EasyLogKitBundle.resources)
    }
}
