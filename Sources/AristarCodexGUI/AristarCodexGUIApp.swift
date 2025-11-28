import SwiftUI
import AppKit

@main
struct AristarCodexGUIApp: App {
    init() {
        // Make sure the app shows up with a Dock icon and can present windows when launched from CLI.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Bring the app to the foreground when launched from Terminal.
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}
