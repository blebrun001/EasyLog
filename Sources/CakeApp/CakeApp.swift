import AppKit
import CakeKit
import SwiftUI

@main
struct CakeApp: App {
    @StateObject private var viewModel = ProjectViewModel()
    @State private var didRequestInitialFocus = false

    var body: some Scene {
        WindowGroup("Cake") {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1320, minHeight: 860)
                .onAppear {
                    guard !didRequestInitialFocus else { return }
                    didRequestInitialFocus = true
                    activateAndFocusWindow()
                }
        }
        .windowResizability(.contentMinSize)
    }

    private func activateAndFocusWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            let candidate = NSApplication.shared.windows.first { $0.canBecomeKey && $0.isVisible }
                ?? NSApplication.shared.windows.first(where: \.canBecomeKey)
            candidate?.makeKeyAndOrderFront(nil)
        }
    }
}
