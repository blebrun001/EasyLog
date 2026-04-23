import AppKit
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
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            VStack(spacing: 0) {
                PreviewContextBar(
                    logs: viewModel.logs,
                    selectedLogIndex: selectedLogIndexBinding,
                    selectedDetailPane: selectedDetailPaneBinding,
                    canOpenSyntheticView: viewModel.canOpenSyntheticView,
                    canRemoveCurrentLog: viewModel.canRemoveCurrentLog,
                    tabTitle: tabTitle(for:index:),
                    onAddLog: viewModel.addLog,
                    onDuplicateLog: viewModel.duplicateCurrentLog,
                    onDeleteLog: { isDeleteLogConfirmationPresented = true }
                )

                VisualizationToolbar(
                    zoom: viewModel.zoom,
                    onSetManualZoom: viewModel.setManualZoom,
                    onFinalizeManualZoomInteraction: viewModel.finalizeManualZoomInteraction,
                    onFitWindow: viewModel.fitToWindow,
                    onToggleSidebar: toggleSidebar,
                    onToggleInspector: viewModel.toggleInspector
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
        .toolbar {
            ToolbarItemGroup {
                Menu {
                    Button("Export…") { viewModel.exportViaPanel() }
                        .help("Export the selected log")
                    Divider()
                    Button("Export All SVG…") { viewModel.exportAllViaPanel(format: .svg) }
                        .help("Export all logs as SVG files")
                    Button("Export All JPG…") { viewModel.exportAllViaPanel(format: .jpg) }
                        .help("Export all logs as JPG files")
                    Button("Export All CSV…") { viewModel.exportAllViaPanel(format: .csv) }
                        .help("Export all logs as CSV files")
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .imageScale(.small)
                }
                .help("Open export options")
            }
        }
        .toolbarRole(.editor)
        .inspector(isPresented: inspectorBinding) {
            SettingsPanelView(settings: settingsBinding)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .accessibilityLabel("Inspector panel")
                .inspectorColumnWidth(min: 240, ideal: 300, max: 380)
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

    private var settingsBinding: Binding<ProjectSettings> {
        Binding(
            get: { viewModel.project.settings },
            set: { newSettings in
                viewModel.updateProjectSettings(newSettings, trigger: .slider)
            }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isInspectorPresented },
            set: { viewModel.setInspectorPresented($0) }
        )
    }

    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }

    private func tabTitle(for log: Project, index: Int) -> String {
        let title = log.metadata.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            return String(format: "Log %d", index + 1)
        }
        return title
    }
}

private struct PreviewContextBar: View {
    let logs: [Project]
    @Binding var selectedLogIndex: Int
    @Binding var selectedDetailPane: EditorPresentationState.DetailPane
    let canOpenSyntheticView: Bool
    let canRemoveCurrentLog: Bool
    let tabTitle: (Project, Int) -> String
    let onAddLog: () -> Void
    let onDuplicateLog: () -> Void
    let onDeleteLog: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                        let isSelected = selectedLogIndex == index
                        Button {
                            selectedLogIndex = index
                        } label: {
                            Text(tabTitle(log, index))
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                                )
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .help("Switch to this log")
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minWidth: 220)

            HStack(spacing: 6) {
                Button(action: onAddLog) {
                    Label("New Log", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .help("Create a new log")

                Button(action: onDuplicateLog) {
                    Label("Duplicate Log", systemImage: "square.on.square")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(logs.isEmpty)
                .help("Duplicate selected log")

                Button(role: .destructive, action: onDeleteLog) {
                    Label("Delete Log", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(!canRemoveCurrentLog)
                .help("Delete selected log")

            }

            Spacer(minLength: 12)

            Picker("View", selection: $selectedDetailPane) {
                ForEach(EditorPresentationState.DetailPane.allCases) { pane in
                    Text(pane.label)
                        .tag(pane)
                        .disabled(pane == .synthetic && !canOpenSyntheticView)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 190)
            .accessibilityLabel("Detail view mode")
            .help("Choose the detail view mode")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

}

private struct VisualizationToolbar: View {
    let zoom: Double
    let onSetManualZoom: (Double, Bool) -> Void
    let onFinalizeManualZoomInteraction: () -> Void
    let onFitWindow: () -> Void
    let onToggleSidebar: () -> Void
    let onToggleInspector: () -> Void
    @State private var isEditingZoomSlider = false

    var body: some View {
        HStack(spacing: 10) {
            Slider(
                value: Binding(
                    get: { zoom },
                    set: { onSetManualZoom($0, isEditingZoomSlider) }
                ),
                in: 0.5...2.5,
                onEditingChanged: { isEditing in
                    isEditingZoomSlider = isEditing
                    if !isEditing {
                        onFinalizeManualZoomInteraction()
                    }
                }
            ) {
                Text("Zoom")
            }
            .frame(width: 180)
            .help("Adjust preview zoom")

            Text("\(Int((zoom * 100).rounded()))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)

            Button(action: onFitWindow) {
                Text("Fit Window")
            }
            .help("Fit the preview to the current window")

            Spacer(minLength: 8)

            Menu {
                Button("Toggle Sidebar", action: onToggleSidebar)
                Button("Toggle Inspector", action: onToggleInspector)
            } label: {
                Label("Panels", systemImage: "rectangle.split.3x1")
            }
            .help("Show or hide the sidebar and inspector panels")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar.opacity(0.88))
        .overlay(alignment: .top) {
            Divider()
        }
    }

}
