import SwiftUI

/// Main split view that hosts the editor sidebar and live render panel.
public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var isDeleteLogConfirmationPresented = false

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 560)
        } detail: {
            VStack(spacing: 0) {
                DetailHeaderBar(
                    selectedDetailPane: selectedDetailPaneBinding,
                    canOpenSyntheticView: viewModel.canOpenSyntheticView,
                    zoomMode: zoomModeBinding,
                    onZoomIn: viewModel.zoomIn,
                    onZoomOut: viewModel.zoomOut,
                    onResetZoom: viewModel.resetZoom
                )

                Group {
                    if viewModel.selectedDetailPane == .synthetic {
                        SyntheticComparisonPopoverView(viewModel: viewModel)
                    } else {
                        RenderPreviewView(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .contain)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .modifier(RenderingInspectorModifier(isPresented: inspectorBinding, settings: settingsBinding))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Picker("Log", selection: selectedLogIndexBinding) {
                    ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                        Text(tabTitle(for: log, index: index)).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 240)
                .accessibilityLabel("Selected log")

                Button {
                    viewModel.addLog()
                } label: {
                    Label("New Log", systemImage: "plus")
                }
                .help("Create a new log")

                Button {
                    viewModel.duplicateCurrentLog()
                } label: {
                    Label("Duplicate Log", systemImage: "square.on.square")
                }
                .disabled(viewModel.logs.isEmpty)
                .help("Duplicate selected log")

                Button(role: .destructive) {
                    isDeleteLogConfirmationPresented = true
                } label: {
                    Label("Delete Log", systemImage: "trash")
                }
                .disabled(!viewModel.canRemoveCurrentLog)
                .help("Delete selected log")
            }

            ToolbarItemGroup {
                Menu {
                    Button("Export SVG…") { viewModel.exportViaPanel(format: .svg) }
                    Button("Export JPG…") { viewModel.exportViaPanel(format: .jpg) }
                    Divider()
                    Button("Export All SVG…") { viewModel.exportAllViaPanel(format: .svg) }
                    Button("Export All JPG…") { viewModel.exportAllViaPanel(format: .jpg) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button {
                    viewModel.toggleInspector()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Show rendering inspector")
            }
        }
        .confirmationDialog(
            "Delete selected log?",
            isPresented: $isDeleteLogConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Log", role: .destructive) {
                viewModel.removeCurrentLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action removes the selected log from the current project.")
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

    private var selectedLogIndexBinding: Binding<Int> {
        Binding(
            get: { viewModel.selectedLogIndex },
            set: { viewModel.selectLog(at: $0) }
        )
    }

    private var selectedDetailPaneBinding: Binding<EditorPresentationState.DetailPane> {
        Binding(
            get: { viewModel.selectedDetailPane },
            set: { viewModel.selectDetailPane($0) }
        )
    }

    private var zoomModeBinding: Binding<ProjectViewModel.ZoomMode> {
        Binding(
            get: { viewModel.zoomMode },
            set: { viewModel.setZoomMode($0) }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isInspectorPresented },
            set: { viewModel.setInspectorPresented($0) }
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

    private func tabTitle(for log: Project, index: Int) -> String {
        let title = log.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return "Log \(index + 1)"
        }
        return title
    }
}

private struct DetailHeaderBar: View {
    @Binding var selectedDetailPane: EditorPresentationState.DetailPane
    let canOpenSyntheticView: Bool
    @Binding var zoomMode: ProjectViewModel.ZoomMode
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onResetZoom: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Picker("View", selection: $selectedDetailPane) {
                ForEach(EditorPresentationState.DetailPane.allCases) { pane in
                    Text(pane.label)
                        .tag(pane)
                        .disabled(pane == .synthetic && !canOpenSyntheticView)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)
            .accessibilityLabel("Detail view mode")

            Divider()
                .frame(height: 18)

            Picker("Zoom", selection: $zoomMode) {
                ForEach(ProjectViewModel.ZoomMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 150)
            .accessibilityLabel("Zoom mode")

            Button(action: onZoomOut) {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .labelStyle(.iconOnly)

            Button(action: onZoomIn) {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .labelStyle(.iconOnly)

            Button(action: onResetZoom) {
                Label("Reset Zoom", systemImage: "arrow.counterclockwise")
            }
            .labelStyle(.iconOnly)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct RenderingInspectorModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var settings: ProjectSettings

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .inspector(isPresented: $isPresented) {
                    inspectorBody
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    inspectorBody
                        .frame(minWidth: 420, minHeight: 420)
                }
        }
    }

    private var inspectorBody: some View {
        SettingsPanelView(settings: $settings)
            .padding()
            .accessibilityLabel("Rendering Inspector")
    }
}
