import SwiftUI
import AppKit

@main
struct AristarCodexGUIApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Make sure the app shows up with a Dock icon and can present windows when launched from CLI.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .accentColor(BrandColor.ion)
                .preferredColorScheme(.dark)
                .task {
                    // Bring the app to the foreground when launched from Terminal.
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onAppear {
                    // Share model reference with AppDelegate for cleanup
                    appDelegate.model = model
                }
        }
        .commands {
            CommandMenu("Project") {
                Button("Open Project…") {
                    openFolderPicker()
                }
                .keyboardShortcut("o", modifiers: [.command])
                
                Divider()
                
                Button("New Worktree") {
                    // This will be handled by the UI since we need branch selection
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(model.currentProject == nil)
            }
            
            CommandMenu("Terminal") {
                Button("Close Terminal") {
                    if let active = model.activeTerminalID {
                        model.closeTerminal(active)
                    }
                }
                .keyboardShortcut("w", modifiers: [.command])
                .disabled(model.activeTerminalID == nil)
                
                Button("Close All Terminals") {
                    model.closeAllTerminals()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(model.openTerminalTabs.isEmpty)
                
                Divider()
                
                Button("Previous Terminal") {
                    switchToPreviousTerminal()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(model.openTerminalTabs.count < 2)
                
                Button("Next Terminal") {
                    switchToNextTerminal()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(model.openTerminalTabs.count < 2)
            }
        }
    }
    
    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                let ref = ProjectRef(url: url)
                model.openProject(ref)
            }
        }
    }
    
    private func switchToPreviousTerminal() {
        guard let active = model.activeTerminalID,
              let currentIndex = model.openTerminalTabs.firstIndex(of: active),
              currentIndex > 0 else { return }
        model.activeTerminalID = model.openTerminalTabs[currentIndex - 1]
    }
    
    private func switchToNextTerminal() {
        guard let active = model.activeTerminalID,
              let currentIndex = model.openTerminalTabs.firstIndex(of: active),
              currentIndex < model.openTerminalTabs.count - 1 else { return }
        model.activeTerminalID = model.openTerminalTabs[currentIndex + 1]
    }
}

/// App delegate to handle app lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    
    func applicationWillTerminate(_ notification: Notification) {
        print("[AppDelegate] Application terminating, stopping all sessions...")
        model?.stopAllSessions()
        print("[AppDelegate] Cleanup complete.")
    }
}
