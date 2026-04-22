import SwiftUI

/// Left-hand editor panel for metadata, unit list, and selected unit form.
public struct ProjectSidebarView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var zeroLevelAltitudeText: String
    @State private var isDeleteUnitConfirmationPresented = false
    @FocusState private var isZeroLevelAltitudeFieldFocused: Bool

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
        self._zeroLevelAltitudeText = State(
            initialValue: Self.altitudeText(from: viewModel.project.settings.zeroLevelAltitudeMeters)
        )
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ProPanelSection(l10n("Log Context"), subtitle: l10n("Metadata and reference altitude")) {
                    ProField(l10n("Log title")) {
                        TextField(l10n("Untitled Stratigraphic Log"), text: $viewModel.project.metadata.title)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel(l10n("Log title"))
                            .help(l10n("Enter the log title"))
                    }

                    ProField(l10n("Zero-level altitude")) {
                        HStack(spacing: 8) {
                            TextField("0", text: zeroLevelAltitudeBinding)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                                .focused($isZeroLevelAltitudeFieldFocused)
                                .accessibilityLabel(l10n("Zero-level altitude"))
                                .help(l10n("Set the zero-level altitude in meters"))
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ProPanelSection(l10n("Units"), subtitle: l10n("Ordered stratigraphic sequence")) {
                    ProBadge("\(viewModel.project.units.count)")
                } content: {
                    List(selection: $viewModel.selectedUnitID) {
                        ForEach(viewModel.project.units) { unit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.name.isEmpty ? l10n("Untitled Unit") : unit.name)
                                    .lineLimit(1)
                                Text("\(unit.thickness, specifier: "%.2f") m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(unit.id)
                        }
                        .onMove(perform: viewModel.moveUnits)
                    }
                    .frame(minHeight: 210, maxHeight: 260)
                    .listStyle(.sidebar)
                    .accessibilityLabel(l10n("Units list"))
                    .help(l10n("Select and reorder stratigraphic units"))

                    HStack(spacing: 8) {
                        Button {
                            viewModel.addUnit()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(l10n("Add unit"))
                        .help(l10n("Add a new unit"))

                        Button {
                            viewModel.moveSelectedUnitUp()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(l10n("Move unit up"))
                        .disabled(viewModel.selectedUnitIndex == nil || viewModel.selectedUnitIndex == 0)
                        .help(l10n("Move the selected unit up"))

                        Button {
                            viewModel.moveSelectedUnitDown()
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(l10n("Move unit down"))
                        .disabled(
                            viewModel.selectedUnitIndex == nil
                                || viewModel.selectedUnitIndex == viewModel.project.units.count - 1
                        )
                        .help(l10n("Move the selected unit down"))

                        Spacer(minLength: 8)

                        Button(role: .destructive) {
                            isDeleteUnitConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(l10n("Delete unit"))
                        .disabled(viewModel.selectedUnitIndex == nil)
                        .help(l10n("Delete the selected unit"))
                    }
                }

                ProPanelSection(
                    l10n("Selected Unit"),
                    subtitle: l10n("Edit lithology, grain size and point features")
                ) {
                    if let index = viewModel.selectedUnitIndex {
                        UnitFormView(unit: $viewModel.project.units[index], viewModel: viewModel)
                            .id(viewModel.project.units[index].id)
                    } else {
                        ProEmptyState(
                            title: l10n("No Unit Selected"),
                            message: l10n("Select a unit in the list to edit its properties."),
                            systemImage: "square.and.pencil"
                        )
                    }
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncZeroLevelAltitudeTextFromModel()
        }
        .onChange(of: viewModel.project.settings.zeroLevelAltitudeMeters) { _, _ in
            guard !isZeroLevelAltitudeFieldFocused else { return }
            syncZeroLevelAltitudeTextFromModel()
        }
        .onChange(of: viewModel.selectedLogIndex) { _, _ in
            isZeroLevelAltitudeFieldFocused = false
            syncZeroLevelAltitudeTextFromModel()
        }
        .confirmationDialog(
            l10n("Delete selected unit?"),
            isPresented: $isDeleteUnitConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(l10n("Delete Unit"), role: .destructive) {
                viewModel.removeSelectedUnit()
            }
            Button(l10n("Cancel"), role: .cancel) {}
        } message: {
            Text(l10n("This action removes the selected unit from the current log."))
        }
    }

    private var zeroLevelAltitudeBinding: Binding<String> {
        Binding(
            get: { zeroLevelAltitudeText },
            set: { raw in
                zeroLevelAltitudeText = raw
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    viewModel.project.settings.zeroLevelAltitudeMeters = nil
                    return
                }
                if let parsed = parseNumber(trimmed) {
                    viewModel.project.settings.zeroLevelAltitudeMeters = parsed
                }
            }
        )
    }

    private func syncZeroLevelAltitudeTextFromModel() {
        zeroLevelAltitudeText = Self.altitudeText(from: viewModel.project.settings.zeroLevelAltitudeMeters)
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

    private static func altitudeText(from value: Double?) -> String {
        guard let value else { return "" }
        return formatNumber(value)
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
        LocalizationService(defaults: .standard, bundle: EasyLogKitBundle.resources).text(key)
    }
}
