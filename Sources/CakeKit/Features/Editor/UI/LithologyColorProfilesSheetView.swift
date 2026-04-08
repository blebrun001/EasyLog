import AppKit
import SwiftUI

/// Popup sheet to manage persistent lithology color profiles and mappings.
public struct LithologyColorProfilesSheetView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var newProfileName: String = ""
    @State private var renameProfileText: String = ""
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
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
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
                    }

                    HStack(spacing: 8) {
                        TextField("Rename active profile", text: $renameProfileText)
                            .textFieldStyle(.roundedBorder)
                        Button("Rename") {
                            guard let activeID = viewModel.activeColorProfileID else { return }
                            viewModel.renameColorProfile(id: activeID, name: renameProfileText)
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 8) {
                        TextField("New profile name", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                        Button("Create") {
                            viewModel.createColorProfile(name: newProfileName)
                            newProfileName = ""
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Delete Active", role: .destructive) {
                            guard let activeID = viewModel.activeColorProfileID else { return }
                            viewModel.deleteColorProfile(id: activeID)
                            renameProfileText = viewModel.activeColorProfileName
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.colorProfiles.count <= 1)
                    }
                }
            }

            ProPanelSection("Lithology Mappings", subtitle: "Set color per USGS lithology code") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(SymbologyLibrary.usgsSection37OfficialSymbols, id: \.code) { symbol in
                            LithologyColorPresetRowView(viewModel: viewModel, symbol: symbol)
                                .id("\(symbol.code)-\(viewModel.activeColorProfileID?.uuidString ?? "none")")
                        }
                    }
                }
                .frame(minHeight: 340)
            }
        }
        .padding(14)
        .onAppear {
            renameProfileText = viewModel.activeColorProfileName
        }
        .onChange(of: viewModel.activeColorProfileID) { _, _ in
            renameProfileText = viewModel.activeColorProfileName
        }
    }

    private var activeProfileBinding: Binding<UUID> {
        Binding(
            get: { viewModel.activeColorProfileID ?? viewModel.colorProfiles.first?.id ?? UUID() },
            set: { viewModel.setActiveColorProfile(id: $0) }
        )
    }
}

private struct LithologyColorPresetRowView: View {
    @ObservedObject var viewModel: ProjectViewModel
    let symbol: USGSLithologySymbol

    @State private var pickerColor: Color = .clear
    @State private var hexText: String = ""

    var body: some View {
        HStack(spacing: 8) {
            Text("\(symbol.label) (\(symbol.code))")
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            ColorPicker("", selection: pickerBinding, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 34)

            TextField("#RRGGBB", text: $hexText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 118)

            Button("Apply") {
                applyHexText()
            }
            .buttonStyle(.bordered)
            .disabled(LithologyColorProfile.normalizedHex(hexText) == nil)

            Button("Reset") {
                viewModel.removeLithologyColorPreset(usgsCode: symbol.code)
                syncFromModel()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.presetColor(for: symbol.code) == nil)
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
                viewModel.setLithologyColorPreset(usgsCode: symbol.code, hex: hex)
                hexText = hex
            }
        )
    }

    private func applyHexText() {
        guard let normalized = LithologyColorProfile.normalizedHex(hexText) else { return }
        viewModel.setLithologyColorPreset(usgsCode: symbol.code, hex: normalized)
        if let nsColor = ColorHex.nsColor(from: normalized) {
            pickerColor = Color(nsColor: nsColor)
        }
        hexText = normalized
    }

    private func syncFromModel() {
        if let presetHex = viewModel.presetColor(for: symbol.code),
           let presetColor = ColorHex.nsColor(from: presetHex) {
            pickerColor = Color(nsColor: presetColor)
            hexText = presetHex
            return
        }

        let fallbackHex = SymbologyLibrary.style(forUSGSCode: symbol.code).fillHex
        if let fallbackColor = ColorHex.nsColor(from: fallbackHex) {
            pickerColor = Color(nsColor: fallbackColor)
        } else {
            pickerColor = .clear
        }
        hexText = ""
    }
}
