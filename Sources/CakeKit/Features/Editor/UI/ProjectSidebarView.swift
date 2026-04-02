import SwiftUI

public struct ProjectSidebarView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                unitsSection
                selectedUnitEditor
            }
            .padding()
        }
    }

    private var unitsSection: some View {
        GroupBox("Units") {
            VStack(spacing: 8) {
                List(selection: $viewModel.selectedUnitID) {
                    ForEach(viewModel.project.units) { unit in
                        HStack {
                            Text(unit.name.isEmpty ? "Untitled Unit" : unit.name)
                            Spacer()
                            Text("\(unit.thickness, specifier: "%.2f") m")
                                .foregroundStyle(.secondary)
                        }
                        .tag(unit.id)
                    }
                    .onMove(perform: viewModel.moveUnits)
                }
                .frame(minHeight: 200, maxHeight: 240)

                HStack {
                    Button("Add") { viewModel.addUnit() }
                    Button("Delete") { viewModel.removeSelectedUnit() }
                        .disabled(viewModel.selectedUnitIndex == nil)
                    Spacer()
                    Text("Drag rows to reorder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var selectedUnitEditor: some View {
        if let index = viewModel.selectedUnitIndex {
            UnitFormView(unit: $viewModel.project.units[index])
            .id(viewModel.project.units[index].id)
        } else {
            GroupBox("Unit Details") {
                Text("Select a unit to edit.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
