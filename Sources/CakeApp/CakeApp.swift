import AppKit
import CakeKit
import SwiftUI

/// App delegate that force-focuses the first app window on launch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        activateAndFocusWindow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.activateAndFocusWindow()
        }
    }

    private func activateAndFocusWindow() {
        _ = NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
        let candidate = NSApp.mainWindow
            ?? NSApp.keyWindow
            ?? NSApp.windows.first { $0.canBecomeKey && $0.isVisible }
            ?? NSApp.windows.first { $0.canBecomeKey }
        candidate?.orderFrontRegardless()
        candidate?.makeMain()
        candidate?.makeKeyAndOrderFront(nil)
    }
}

@main
/// SwiftUI application entry point and dependency composition root.
struct CakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ProjectViewModel()

    private func showAboutPanel() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage
        ])
    }

    var body: some Scene {
        WindowGroup("Cake") {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1320, minHeight: 860)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Cake") {
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
            }
        }
    }
}
