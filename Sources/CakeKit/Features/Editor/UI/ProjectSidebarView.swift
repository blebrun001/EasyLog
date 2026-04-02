import SwiftUI

public struct ProjectSidebarView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                projectMetadataSection
                unitsSection
                selectedUnitEditor
            }
            .padding()
        }
    }

    private var projectMetadataSection: some View {
        GroupBox("Project") {
            VStack(spacing: 8) {
                TextField("Title", text: $viewModel.project.metadata.title)
                TextField("Author", text: $viewModel.project.metadata.author)
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                }
                .frame(minHeight: 200, maxHeight: 240)

                HStack {
                    Button("Add") { viewModel.addUnit() }
                    Button("Delete") { viewModel.removeSelectedUnit() }
                        .disabled(viewModel.selectedUnitIndex == nil)
                    Spacer()
                    Button("Up") { viewModel.moveSelectedUnitUp() }
                        .disabled((viewModel.selectedUnitIndex ?? 0) <= 0)
                    Button("Down") { viewModel.moveSelectedUnitDown() }
                        .disabled({
                            guard let index = viewModel.selectedUnitIndex else { return true }
                            return index >= viewModel.project.units.count - 1
                        }())
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
