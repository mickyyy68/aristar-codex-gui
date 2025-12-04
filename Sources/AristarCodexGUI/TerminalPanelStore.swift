import SwiftUI

/// State persistence for the terminal panel
struct TerminalPanelStore {
    private static let openTabsKey = "aristar.terminalPanel.openTabs"
    private static let activeTabKey = "aristar.terminalPanel.activeTab"
    private static let panelWidthKey = "aristar.terminalPanel.width"
    private static let currentProjectKey = "aristar.currentProject"
    
    static func saveOpenTabs(_ tabs: [String]) {
        UserDefaults.standard.set(tabs, forKey: openTabsKey)
    }
    
    static func loadOpenTabs() -> [String] {
        UserDefaults.standard.stringArray(forKey: openTabsKey) ?? []
    }
    
    static func saveActiveTab(_ id: String?) {
        UserDefaults.standard.set(id, forKey: activeTabKey)
    }
    
    static func loadActiveTab() -> String? {
        UserDefaults.standard.string(forKey: activeTabKey)
    }
    
    static func savePanelWidth(_ width: CGFloat) {
        UserDefaults.standard.set(Double(width), forKey: panelWidthKey)
    }
    
    static func loadPanelWidth() -> CGFloat {
        let value = UserDefaults.standard.double(forKey: panelWidthKey)
        return value > 0 ? CGFloat(value) : 500
    }
    
    static func saveCurrentProject(_ project: ProjectRef?) {
        if let project = project {
            if let data = try? JSONEncoder().encode(project) {
                UserDefaults.standard.set(data, forKey: currentProjectKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: currentProjectKey)
        }
    }
    
    static func loadCurrentProject() -> ProjectRef? {
        guard let data = UserDefaults.standard.data(forKey: currentProjectKey),
              let project = try? JSONDecoder().decode(ProjectRef.self, from: data) else {
            return nil
        }
        // Verify the project still exists
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: project.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return project
    }
}
