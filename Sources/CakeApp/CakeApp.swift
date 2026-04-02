import AppKit
import CakeKit
import SwiftUI

@main
struct CakeApp: App {
    @StateObject private var viewModel = ProjectViewModel()

    var body: some Scene {
        WindowGroup("Cake") {
            MainContentView(viewModel: viewModel)
                .frame(minWidth: 1320, minHeight: 860)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .windowResizability(.contentMinSize)
    }
}
