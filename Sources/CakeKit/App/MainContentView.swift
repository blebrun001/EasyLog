import SwiftUI

public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 420, ideal: 500, max: 580)
        } detail: {
            VStack(spacing: 0) {
                RenderPreviewView(viewModel: viewModel)
                Divider()
                HStack(alignment: .top, spacing: 20) {
                    SettingsPanelView(settings: $viewModel.project.settings)
                        .frame(maxWidth: 360, alignment: .leading)
                    Spacer()
                }
                .padding()
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
}
