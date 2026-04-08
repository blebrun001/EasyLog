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
                ProPanelSection("Log Context", subtitle: "Metadata and reference altitude") {
                    ProField("Log title") {
                        TextField("Untitled Stratigraphic Log", text: $viewModel.project.metadata.title)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Log title")
                            .help("Enter the log title")
                    }

                    ProField("Zero-level altitude") {
                        HStack(spacing: 8) {
                            TextField("0", text: zeroLevelAltitudeBinding)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                                .focused($isZeroLevelAltitudeFieldFocused)
                                .accessibilityLabel("Zero-level altitude")
                                .help("Set the zero-level altitude in meters")
                            Text("m")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ProPanelSection("Units", subtitle: "Ordered stratigraphic sequence") {
                    ProBadge("\(viewModel.project.units.count)")
                } content: {
                    List(selection: $viewModel.selectedUnitID) {
                        ForEach(viewModel.project.units) { unit in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.name.isEmpty ? "Untitled Unit" : unit.name)
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
                    .listStyle(.inset)
                    .accessibilityLabel("Units list")
                    .help("Select and reorder stratigraphic units")

                    HStack(spacing: 8) {
                        Button {
                            viewModel.addUnit()
                        } label: {
                            Label("Add Unit", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Add a new unit")

                        Button {
                            viewModel.moveSelectedUnitUp()
                        } label: {
                            Label("Move Up", systemImage: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.selectedUnitIndex == nil || viewModel.selectedUnitIndex == 0)
                        .help("Move the selected unit up")

                        Button {
                            viewModel.moveSelectedUnitDown()
                        } label: {
                            Label("Move Down", systemImage: "arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            viewModel.selectedUnitIndex == nil
                                || viewModel.selectedUnitIndex == viewModel.project.units.count - 1
                        )
                        .help("Move the selected unit down")

                        Spacer(minLength: 8)

                        Button(role: .destructive) {
                            isDeleteUnitConfirmationPresented = true
                        } label: {
                            Label("Delete Unit", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.selectedUnitIndex == nil)
                        .help("Delete the selected unit")
                    }
                }

                ProPanelSection("Selected Unit", subtitle: "Edit lithology, grain size and point features") {
                    if let index = viewModel.selectedUnitIndex {
                        UnitFormView(unit: $viewModel.project.units[index], viewModel: viewModel)
                            .id(viewModel.project.units[index].id)
                    } else {
                        ProEmptyState(
                            title: "No Unit Selected",
                            message: "Select a unit in the list to edit its properties.",
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
            "Delete selected unit?",
            isPresented: $isDeleteUnitConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Unit", role: .destructive) {
                viewModel.removeSelectedUnit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action removes the selected unit from the current log.")
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
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()
}
