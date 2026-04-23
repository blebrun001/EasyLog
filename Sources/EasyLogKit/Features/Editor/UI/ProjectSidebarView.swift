import SwiftUI

/// Left-hand editor panel for metadata, unit list, and selected unit form.
public struct ProjectSidebarView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    private let numberIO = LocalizedNumberIO(defaults: .standard)
    @State private var zeroLevelAltitudeText: String
    @State private var isDeleteUnitConfirmationPresented = false
    @FocusState private var isZeroLevelAltitudeFieldFocused: Bool

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
        let numberIO = LocalizedNumberIO(defaults: .standard)
        let initialAltitudeText = viewModel.project.settings.zeroLevelAltitudeMeters.map { numberIO.format($0) } ?? ""
        self._zeroLevelAltitudeText = State(initialValue: initialAltitudeText)
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
                                Text("\(numberIO.format(unit.thickness, minFractionDigits: 2, maxFractionDigits: 2)) m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(unit.id)
                        }
                        .onMove(perform: viewModel.moveUnits)
                    }
                    .frame(minHeight: 210, maxHeight: 260)
                    .listStyle(.sidebar)
                    .accessibilityLabel("Units list")
                    .help("Select and reorder stratigraphic units")

                    HStack(spacing: 8) {
                        Button {
                            viewModel.addUnit()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Add unit")
                        .help("Add a new unit")

                        Button {
                            viewModel.moveSelectedUnitUp()
                        } label: {
                            Image(systemName: "arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Move unit up")
                        .disabled(viewModel.selectedUnitIndex == nil || viewModel.selectedUnitIndex == 0)
                        .help("Move the selected unit up")

                        Button {
                            viewModel.moveSelectedUnitDown()
                        } label: {
                            Image(systemName: "arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Move unit down")
                        .disabled(
                            viewModel.selectedUnitIndex == nil
                                || viewModel.selectedUnitIndex == viewModel.project.units.count - 1
                        )
                        .help("Move the selected unit down")

                        Spacer(minLength: 8)

                        Button(role: .destructive) {
                            isDeleteUnitConfirmationPresented = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Delete unit")
                        .disabled(viewModel.selectedUnitIndex == nil)
                        .help("Delete the selected unit")
                    }
                }

                ProPanelSection(
                    "Selected Unit",
                    subtitle: "Edit lithology, grain size and point features"
                ) {
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
        zeroLevelAltitudeText = altitudeText(from: viewModel.project.settings.zeroLevelAltitudeMeters)
    }

    private func parseNumber(_ raw: String) -> Double? {
        numberIO.parse(raw)
    }

    private func formatNumber(_ value: Double) -> String {
        numberIO.format(value)
    }

    private func altitudeText(from value: Double?) -> String {
        guard let value else { return "" }
        return formatNumber(value)
    }}
