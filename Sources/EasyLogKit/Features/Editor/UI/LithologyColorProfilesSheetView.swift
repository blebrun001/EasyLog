import AppKit
import SwiftUI

/// Popup sheet to manage persistent lithology color profiles and mappings.
public struct LithologyColorProfilesSheetView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var newProfileName: String = ""
    @State private var renameProfileText: String = ""
    @State private var selectedLithologyCategory: USGSLithologyCategory = .coarseClastics
    @State private var selectedLithologyCode: Int = 0
    @State private var addPickerColor: Color = .clear
    @State private var addHexText: String = ""
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lithology Color Profiles")
                        .font(.title3.weight(.semibold))
                    Text("Persistent, app-level presets. Apply manually from Selected Unit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    viewModel.flushPendingColorPresetPersistence()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .help("Close color profile management")
            }

            ProPanelSection("Profiles", subtitle: "Create, rename, delete and select active profile") {
                VStack(alignment: .leading, spacing: 10) {
                    ProField("Active profile") {
                        Picker("Active profile", selection: activeProfileBinding) {
                            ForEach(viewModel.colorProfiles) { profile in
                                Text(profile.name).tag(profile.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 320, alignment: .leading)
                        .help("Choose the active color profile")
                    }

                    HStack(spacing: 8) {
                        TextField("Rename active profile", text: $renameProfileText)
                            .textFieldStyle(.roundedBorder)
                            .help("Enter a new name for the active profile")
                        Button("Rename") {
                            guard let activeID = viewModel.activeColorProfileID else { return }
                            viewModel.renameColorProfile(id: activeID, name: renameProfileText)
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.bordered)
                        .help("Rename the active profile")
                    }

                    HStack(spacing: 8) {
                        TextField("New profile name", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                            .help("Enter a name for a new profile")
                        Button("Create") {
                            viewModel.createColorProfile(name: newProfileName)
                            newProfileName = ""
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Create a new color profile")

                        Button("Delete Active", role: .destructive) {
                            guard let activeID = viewModel.activeColorProfileID else { return }
                            viewModel.deleteColorProfile(id: activeID)
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.colorProfiles.count <= 1)
                        .help("Delete the active color profile")
                    }
                }
            }

            ProPanelSection("Lithology Mappings", subtitle: "Add custom colors by selecting category, lithology, then color") {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 10) {
                        fieldGroup("Category") {
                            Picker("Category", selection: $selectedLithologyCategory) {
                                ForEach(availableLithologyCategories, id: \.self) { category in
                                    Text(category.label).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help("Choose a lithology category")
                            .onChange(of: selectedLithologyCategory) { _, _ in
                                normalizeLithologySelection()
                                clearAddColorInputs()
                            }
                        }

                        fieldGroup("Lithology") {
                            Picker("Lithology", selection: $selectedLithologyCode) {
                                ForEach(lithologySymbolsInSelectedCategory, id: \.code) { symbol in
                                    Text("\(symbol.label) (\(symbol.code))").tag(symbol.code)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help("Choose a lithology to map")
                            .onChange(of: selectedLithologyCode) { _, _ in
                                clearAddColorInputs()
                            }
                        }

                        HStack(spacing: 8) {
                            ColorPicker("", selection: addColorBinding, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 34)
                                .help("Pick a color for the selected lithology")

                            TextField("#RRGGBB", text: $addHexText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 118)
                                .help("Enter color in hex format")

                            Button("Add Custom Color") {
                                addCustomColorMapping()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(LithologyColorProfile.normalizedHex(addHexText) == nil || !isSelectedLithologyValid)
                            .help("Add or update the custom color mapping")
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if activeMappingCodes.isEmpty {
                        Text("No custom lithology mappings yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(activeMappingCodes, id: \.self) { code in
                                    LithologyColorPresetRowView(viewModel: viewModel, usgsCode: code)
                                        .id("\(code)-\(viewModel.activeColorProfileID?.uuidString ?? "none")")
                                }
                            }
                        }
                        .frame(minHeight: 280)
                    }
                }
            }
        }
        .padding(14)
        .onAppear {
            renameProfileText = viewModel.activeColorProfileName
            normalizeLithologySelection()
        }
        .onChange(of: viewModel.activeColorProfileID) { _, _ in
            renameProfileText = viewModel.activeColorProfileName
            normalizeLithologySelection()
            clearAddColorInputs()
        }
        .onDisappear {
            viewModel.flushPendingColorPresetPersistence()
        }
    }

    private var activeProfileBinding: Binding<UUID> {
        Binding(
            get: { viewModel.activeColorProfileID ?? viewModel.colorProfiles.first?.id ?? UUID() },
            set: { viewModel.setActiveColorProfile(id: $0) }
        )
    }

    private var activeProfileMappings: [Int: String] {
        guard let activeID = viewModel.activeColorProfileID,
              let active = viewModel.colorProfiles.first(where: { $0.id == activeID }) else {
            return [:]
        }
        return active.mappings
    }

    private var activeMappingCodes: [Int] {
        activeProfileMappings.keys.sorted()
    }

    private var availableLithologyCategories: [USGSLithologyCategory] {
        USGSLithologyCategory.allCases.filter { !SymbologyLibrary.symbols(in: $0).isEmpty }
    }

    private var lithologySymbolsInSelectedCategory: [USGSLithologySymbol] {
        SymbologyLibrary.symbols(in: selectedLithologyCategory)
    }

    private var isSelectedLithologyValid: Bool {
        lithologySymbolsInSelectedCategory.contains(where: { $0.code == selectedLithologyCode })
    }

    private var addColorBinding: Binding<Color> {
        Binding(
            get: { addPickerColor },
            set: { newColor in
                addPickerColor = newColor
                let nsColor = NSColor(newColor)
                guard let hex = ColorHex.hex(from: nsColor) else { return }
                addHexText = hex
            }
        )
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
    }

    private func clearAddColorInputs() {
        addPickerColor = .clear
        addHexText = ""
    }

    private func addCustomColorMapping() {
        guard isSelectedLithologyValid else { return }
        guard let normalized = LithologyColorProfile.normalizedHex(addHexText) else { return }
        viewModel.setLithologyColorPreset(usgsCode: selectedLithologyCode, hex: normalized)
        addHexText = normalized
        if let nsColor = ColorHex.nsColor(from: normalized) {
            addPickerColor = Color(nsColor: nsColor)
        }
    }

    private func fieldGroup<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        ProField(label) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LithologyColorPresetRowView: View {
    @ObservedObject var viewModel: ProjectViewModel
    let usgsCode: Int

    @State private var pickerColor: Color = .clear
    @State private var hexText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("\(SymbologyLibrary.label(forUSGSCode: usgsCode)) (\(usgsCode))")
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34)
                .help("Pick a custom mapped color")

            TextField("#RRGGBB", text: $hexText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 118)
                .help("Enter mapped color in hex format")

            Button("Apply") {
                applyHexText()
            }
            .buttonStyle(.bordered)
            .disabled(LithologyColorProfile.normalizedHex(hexText) == nil)
            .help("Apply this mapped color")

            Button("Reset") {
                viewModel.removeLithologyColorPreset(usgsCode: usgsCode)
                syncFromModel()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.presetColor(for: usgsCode) == nil)
            .help("Reset to the default mapped color")
        }
        .onAppear {
            syncFromModel()
        }
    }

    private var pickerBinding: Binding<Color> {
        Binding(
            get: { pickerColor },
            set: { newColor in
                pickerColor = newColor
                let nsColor = NSColor(newColor)
                guard let hex = ColorHex.hex(from: nsColor) else { return }
                viewModel.setLithologyColorPreset(usgsCode: usgsCode, hex: hex)
                hexText = hex
            }
        )
    }

    private func applyHexText() {
        guard let normalized = LithologyColorProfile.normalizedHex(hexText) else { return }
        viewModel.setLithologyColorPreset(usgsCode: usgsCode, hex: normalized)
        if let nsColor = ColorHex.nsColor(from: normalized) {
            pickerColor = Color(nsColor: nsColor)
        }
        hexText = normalized
    }

    private func syncFromModel() {
        if let presetHex = viewModel.presetColor(for: usgsCode),
           let presetColor = ColorHex.nsColor(from: presetHex) {
            pickerColor = Color(nsColor: presetColor)
            hexText = presetHex
            return
        }

        let fallbackHex = SymbologyLibrary.style(forUSGSCode: usgsCode).fillHex
        if let fallbackColor = ColorHex.nsColor(from: fallbackHex) {
            pickerColor = Color(nsColor: fallbackColor)
        } else {
            pickerColor = .clear
        }
        hexText = ""
    }
}
