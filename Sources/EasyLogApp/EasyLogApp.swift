import AppKit
import EasyLogKit
import SwiftUI

@main
/// SwiftUI application entry point and dependency composition root.
struct EasyLogApp: App {
    @StateObject private var viewModel = ProjectViewModel()

    private func showAboutPanel() {
        let version = appVersion
        let credits = """
        Version \(version)
        License: GNU General Public License v3.0 (GPL-3.0)
        Author: Brice Lebrun
        """

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any,
            .applicationVersion: version,
            .credits: NSAttributedString(string: credits)
        ])
    }

    var body: some Scene {
        WindowGroup {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1280, height: 840)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About EasyLog") {
                    showAboutPanel()
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New") { viewModel.newProject() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Open…") { viewModel.openProjectViaPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") { viewModel.saveProjectViaPanelIfNeeded() }
                    .keyboardShortcut("s", modifiers: [.command])
            }

            CommandGroup(after: .saveItem) {
                Divider()
                Button("Export…") { viewModel.exportViaPanel() }
                Divider()
                Button("Export All SVG…") { viewModel.exportAllViaPanel(format: .svg) }
                Button("Export All JPG…") { viewModel.exportAllViaPanel(format: .jpg) }
                Button("Export All CSV…") { viewModel.exportAllViaPanel(format: .csv) }
            }

            CommandGroup(after: .sidebar) {
                Button("Toggle Inspector") { viewModel.toggleInspector() }
                    .keyboardShortcut("i", modifiers: [.command, .option])
            }

            CommandGroup(after: .pasteboard) {
                Button("New Log") { viewModel.addLog() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Duplicate Log") { viewModel.duplicateCurrentLog() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Delete Log") { viewModel.removeCurrentLog() }
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(!viewModel.canRemoveCurrentLog)
                Divider()
                Button("Add Unit") { viewModel.addUnit() }
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                Button("Delete Selected Unit") { viewModel.removeSelectedUnit() }
                    .keyboardShortcut(.delete, modifiers: [.command, .option])
                    .disabled(viewModel.selectedUnitIndex == nil)
                Divider()
                Button("Move Unit Up") { viewModel.moveSelectedUnitUp() }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(viewModel.selectedUnitIndex == nil || viewModel.selectedUnitIndex == 0)
                Button("Move Unit Down") { viewModel.moveSelectedUnitDown() }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(viewModel.selectedUnitIndex == nil || viewModel.selectedUnitIndex == viewModel.project.units.count - 1)
            }

            CommandMenu("View") {
                Section("Zoom") {
                    Button("Zoom In") { viewModel.zoomIn() }
                        .keyboardShortcut("=", modifiers: [.command])
                    Button("Zoom Out") { viewModel.zoomOut() }
                        .keyboardShortcut("-", modifiers: [.command])
                    Button("Fit Window") { viewModel.fitToWindow() }
                        .keyboardShortcut("0", modifiers: [.command])
                }

                Picker("Detail View", selection: detailPaneBinding) {
                    ForEach(EditorPresentationState.DetailPane.allCases) { pane in
                        Text(pane.label)
                            .tag(pane)
                            .disabled(pane == .synthetic && !viewModel.canOpenSyntheticView)
                    }
                }
            }
        }

        Settings {
            AppSettingsView(viewModel: viewModel)
                .frame(minWidth: 420, minHeight: 260)
        }
    }

    private var detailPaneBinding: Binding<EditorPresentationState.DetailPane> {
        Binding(
            get: { viewModel.selectedDetailPane },
            set: { viewModel.selectDetailPane($0) }
        )
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        if let shortVersion = info?["CFBundleShortVersionString"] as? String,
           !shortVersion.isEmpty {
            return shortVersion
        }
        if let buildVersion = info?["CFBundleVersion"] as? String,
           !buildVersion.isEmpty {
            return buildVersion
        }
        return "Unknown"
    }
}

private struct AppSettingsView: View {
    @ObservedObject var viewModel: ProjectViewModel

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show inspector on launch", isOn: inspectorOnLaunchBinding)
                Picker("Default detail view", selection: defaultDetailPaneBinding) {
                    ForEach(EditorPresentationState.DetailPane.allCases) { pane in
                        Text(pane.label).tag(pane)
                    }
                }
            }

            Section("Lithology Colors") {
                Picker("Active color profile", selection: activeColorProfileBinding) {
                    ForEach(viewModel.colorProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                Text("Applies globally to new and existing projects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(12)
    }

    private var inspectorOnLaunchBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showsInspectorOnLaunchPreference },
            set: { viewModel.setShowsInspectorOnLaunchPreference($0) }
        )
    }

    private var defaultDetailPaneBinding: Binding<EditorPresentationState.DetailPane> {
        Binding(
            get: { viewModel.defaultDetailPanePreference },
            set: { viewModel.setDefaultDetailPanePreference($0) }
        )
    }

    private var activeColorProfileBinding: Binding<UUID> {
        Binding(
            get: { viewModel.activeColorProfileID ?? viewModel.colorProfiles.first?.id ?? UUID() },
            set: { viewModel.setActiveColorProfile(id: $0) }
        )
    }
}
