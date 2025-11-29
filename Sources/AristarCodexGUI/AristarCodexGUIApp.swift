import SwiftUI
import AppKit

@main
struct AristarCodexGUIApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Make sure the app shows up with a Dock icon and can present windows when launched from CLI.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task {
                    // Bring the app to the foreground when launched from Terminal.
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandMenu("Navigation") {
                Button("Hubs") {
                    model.selectedTab = .hubs
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Working Set") {
                    model.selectedTab = .workingSet
                }
                .keyboardShortcut("2", modifiers: [.command])
            }
        }
    }
}
