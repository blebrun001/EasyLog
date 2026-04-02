import SwiftUI

public struct ProjectSidebarView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var hoveredUnitID: UUID?

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                card {
                    metadataSection
                }
                card {
                    unitsSection
                }
                card {
                    selectedUnitEditor
                }
            }
            .padding()
            .padding(.bottom, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Project Editor")
                .font(.title3)
                .fontWeight(.semibold)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Project")
            TextField("Log title", text: $viewModel.project.metadata.title)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var unitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader("Units")
                Spacer()
                Text("\(viewModel.project.units.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            if viewModel.project.units.isEmpty {
                emptyState(
                    title: "No units yet",
                    systemImage: "square.stack.3d.up.slash"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                List(selection: $viewModel.selectedUnitID) {
                    ForEach(viewModel.project.units) { unit in
                        HStack(alignment: .center, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(unit.name.isEmpty ? "Untitled Unit" : unit.name)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("\(unit.thickness, specifier: "%.2f") m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .tag(unit.id)
                        .listRowSeparator(.hidden)
                        .listRowBackground(rowBackground(for: unit.id))
                        .onHover { isHovering in
                            hoveredUnitID = isHovering ? unit.id : nil
                        }
                    }
                    .onMove(perform: viewModel.moveUnits)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 200, maxHeight: 240)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.addUnit()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.removeSelectedUnit()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(viewModel.selectedUnitIndex == nil)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var selectedUnitEditor: some View {
        if let index = viewModel.selectedUnitIndex {
            UnitFormView(unit: $viewModel.project.units[index])
                .id(viewModel.project.units[index].id)
        } else {
            emptyState(
                title: "No unit selected",
                systemImage: "slider.horizontal.below.square.and.square.filled"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func emptyState(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
    }

    private func rowBackground(for unitID: UUID) -> some View {
        let isSelected = viewModel.selectedUnitID == unitID
        let isHovered = hoveredUnitID == unitID
        let opacity: Double
        if isSelected {
            opacity = 0.22
        } else if isHovered {
            opacity = 0.10
        } else {
            opacity = 0.0
        }

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(opacity))
            .padding(.vertical, 2)
    }
}
