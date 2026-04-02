import AppKit
import CakeKit
import SwiftUI

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
struct CakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = ProjectViewModel()

    var body: some Scene {
        WindowGroup("Cake") {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1320, minHeight: 860)
        }
        .windowResizability(.contentMinSize)
    }
}
