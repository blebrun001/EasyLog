import SwiftUI

/// Main split view that hosts the editor sidebar and live render panel.
public struct MainContentView: View {
    @ObservedObject private var viewModel: ProjectViewModel
    @State private var isDeleteLogConfirmationPresented = false
    @State private var isOptionsPopoverPresented = false

    public init(viewModel: ProjectViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationSplitView {
            ProjectSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 560)
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
                    isResetZoomVisible: viewModel.canResetManualZoom,
                    onResetZoom: viewModel.resetZoom,
                    isOptionsPopoverPresented: $isOptionsPopoverPresented,
                    settings: settingsBinding
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
            ToolbarItemGroup {
                Menu {
                    Button("Export SVG…") { viewModel.exportViaPanel(format: .svg) }
                    Button("Export JPG…") { viewModel.exportViaPanel(format: .jpg) }
                    Divider()
                    Button("Export All SVG…") { viewModel.exportAllViaPanel(format: .svg) }
                    Button("Export All JPG…") { viewModel.exportAllViaPanel(format: .jpg) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .imageScale(.small)
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
                .help("Create a new log")

                Button(action: onDuplicateLog) {
                    Label("Duplicate Log", systemImage: "square.on.square")
                }
                .labelStyle(.iconOnly)
                .disabled(logs.isEmpty)
                .help("Duplicate selected log")

                Button(role: .destructive, action: onDeleteLog) {
                    Label("Delete Log", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct VisualizationToolbar: View {
    let isResetZoomVisible: Bool
    let onResetZoom: () -> Void
    @Binding var isOptionsPopoverPresented: Bool
    @Binding var settings: ProjectSettings

    var body: some View {
        HStack(spacing: 10) {
            if isResetZoomVisible {
                Button(action: onResetZoom) {
                    Text("reset zoom")
                }
            }

            Spacer(minLength: 8)

            Button {
                isOptionsPopoverPresented.toggle()
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
            .popover(isPresented: $isOptionsPopoverPresented, arrowEdge: .top) {
                ViewOptionsPopover(settings: $settings)
                    .frame(minWidth: 360)
            }
            .help("Show advanced view options")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar.opacity(0.88))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct ViewOptionsPopover: View {
    @Binding var settings: ProjectSettings

    var body: some View {
        Form {
            Section("Scale") {
                LabeledContent("Vertical scale") {
                    Text("\(settings.verticalScale, specifier: "%.0f") px/m")
                        .foregroundStyle(.secondary)
                }
                Slider(value: verticalScaleBinding, in: 8...120)
                    .accessibilityLabel("Vertical scale")

                LabeledContent("Symbol scale") {
                    Text("\(settings.symbolScale, specifier: "%.2f")x")
                        .foregroundStyle(.secondary)
                }
                Slider(value: symbolScaleBinding, in: 0.35...3.0)
                    .accessibilityLabel("Symbol scale")

                LabeledContent("Point icon size") {
                    Text("\(settings.pointFeatureIconSize, specifier: "%.1f") px")
                        .foregroundStyle(.secondary)
                }
                Slider(value: pointFeatureIconSizeBinding, in: 3...18)
                    .accessibilityLabel("Point feature icon size")

                Picker("Scale unit", selection: $settings.depthScaleUnit) {
                    ForEach(DepthScaleUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
            }

            Section("Visibility") {
                Toggle("Use absolute altitude", isOn: useAbsoluteAltitudeBinding)
                    .accessibilityLabel("Use absolute altitude")
                Toggle("Show legend", isOn: $settings.showLegend)
                Toggle("Show depth scale", isOn: $settings.showScale)
                Toggle("Show grain size scale", isOn: $settings.showGrainSizeScale)
                Toggle("Show USGS codes in labels", isOn: $settings.showUSGSCodesInLithologyLabels)
                Toggle("Show log title", isOn: $settings.showLogTitle)
            }
        }
        .formStyle(.grouped)
        .padding(12)
        .accessibilityLabel("View options")
    }

    private var verticalScaleBinding: Binding<Double> {
        Binding(
            get: { settings.verticalScale },
            set: { settings.verticalScale = snapped($0, step: 1, range: 8...120) }
        )
    }

    private var symbolScaleBinding: Binding<Double> {
        Binding(
            get: { settings.symbolScale },
            set: { settings.symbolScale = snapped($0, step: 0.05, range: 0.35...3.0) }
        )
    }

    private var useAbsoluteAltitudeBinding: Binding<Bool> {
        Binding(
            get: { settings.useAbsoluteAltitude },
            set: { isEnabled in
                settings.useAbsoluteAltitude = isEnabled
                if isEnabled {
                    settings.zeroLevelAltitudeMeters = settings.zeroLevelAltitudeMeters ?? 0
                }
            }
        )
    }

    private var pointFeatureIconSizeBinding: Binding<Double> {
        Binding(
            get: { settings.pointFeatureIconSize },
            set: { settings.pointFeatureIconSize = snapped($0, step: 0.5, range: 3...18) }
        )
    }

    private func snapped(_ value: Double, step: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        let stepped = (clamped / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
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
