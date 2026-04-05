import SwiftUI

/// Main split view that hosts the editor sidebar and live render panel.
public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var isSyntheticTabSelected = false

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 520)
        } detail: {
            VStack(spacing: 0) {
                logTabsBar
                Divider()
                if isSyntheticTabSelected {
                    SyntheticComparisonPopoverView(viewModel: viewModel)
                } else {
                    RenderPreviewView(viewModel: viewModel)
                }
                Divider()
                Text(viewModel.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .accessibilityLabel("Status")
                    .accessibilityValue(viewModel.statusMessage)
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
        .onChange(of: viewModel.canOpenSyntheticView) { canOpen in
            if !canOpen {
                isSyntheticTabSelected = false
            }
        }
    }

    private var logTabsBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                        HStack(spacing: 6) {
                            Button {
                                isSyntheticTabSelected = false
                                viewModel.selectLog(at: index)
                            } label: {
                                Text(tabTitle(for: log, index: index))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.plain)

                            if viewModel.logs.count > 1 {
                                Button {
                                    isSyntheticTabSelected = false
                                    viewModel.removeLog(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove log \(index + 1)")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(index == viewModel.selectedLogIndex ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.12))
                        )
                    }

                    Button {
                        guard viewModel.canOpenSyntheticView else { return }
                        isSyntheticTabSelected = true
                    } label: {
                        Text("Synthetic View")
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canOpenSyntheticView)
                    .background(
                        Capsule()
                            .fill(isSyntheticTabSelected ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.12))
                    )
                    .opacity(viewModel.canOpenSyntheticView ? 1 : 0.5)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Button {
                viewModel.addLog()
            } label: {
                Label("New Log", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Button {
                viewModel.duplicateCurrentLog()
            } label: {
                Label("Duplicate Log", systemImage: "square.on.square")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.logs.isEmpty)
            .padding(.trailing, 12)
        }
    }

    private func tabTitle(for log: Project, index: Int) -> String {
        let title = log.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return "Log \(index + 1)"
        }
        return title
    }
}
