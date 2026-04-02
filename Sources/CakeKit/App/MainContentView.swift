import SwiftUI

/// Main split view that hosts the editor sidebar and live render panel.
public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 520)
        } detail: {
            VStack(spacing: 0) {
                RenderPreviewView(viewModel: viewModel)
                Divider()
                HStack(alignment: .top, spacing: 20) {
                    SettingsPanelView(settings: settingsBinding)
                        .frame(maxWidth: 360, alignment: .leading)
                    Spacer()
                }
                .padding()
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
    }

    private var settingsBinding: Binding<ProjectSettings> {
        Binding(
            get: { viewModel.project.settings },
            set: { newSettings in
                var updatedProject = viewModel.project
                updatedProject.settings = newSettings
                viewModel.project = updatedProject
            }
        )
    }
}
