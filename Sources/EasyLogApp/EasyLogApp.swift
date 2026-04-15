import AppKit
import EasyLogKit
import SwiftUI

@main
/// SwiftUI application entry point and dependency composition root.
struct EasyLogApp: App {
    @StateObject private var viewModel = ProjectViewModel()

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any
        ])
    }

    var body: some Scene {
        WindowGroup {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .windowResizability(.contentMinSize)
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
                Button("Export SVG…") { viewModel.exportViaPanel(format: .svg) }
                Button("Export JPG…") { viewModel.exportViaPanel(format: .jpg) }
                Divider()
                Button("Export All SVG…") { viewModel.exportAllViaPanel(format: .svg) }
                Button("Export All JPG…") { viewModel.exportAllViaPanel(format: .jpg) }
            }

            CommandGroup(replacing: .toolbar) {
                Button("Show Inspector") { viewModel.toggleInspector() }
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
                    .keyboardShortcut(.delete, modifiers: [])
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
                    Button("Zoom Out") { viewModel.zoomOut() }
                    Button("Fit Window") { viewModel.fitToWindow() }
                    Button("Reset Zoom") { viewModel.resetZoom() }
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
    }

    private var detailPaneBinding: Binding<EditorPresentationState.DetailPane> {
        Binding(
            get: { viewModel.selectedDetailPane },
            set: { viewModel.selectDetailPane($0) }
        )
    }
}
