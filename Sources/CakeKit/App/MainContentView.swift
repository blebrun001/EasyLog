import SwiftUI

/// Main split view that hosts the editor sidebar and live render panel.
public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            logTabsBar
            Divider()
            NavigationSplitView {
                ProjectSidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 520)
            } detail: {
                VStack(spacing: 0) {
                    RenderPreviewView(viewModel: viewModel)
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
    }

    private var logTabsBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                        Button {
                            viewModel.selectLog(at: index)
                        } label: {
                            Text(tabTitle(for: log, index: index))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(
                            Capsule()
                                .fill(index == viewModel.selectedLogIndex ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.12))
                        )
                    }
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
