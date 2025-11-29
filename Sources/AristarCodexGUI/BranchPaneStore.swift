import Foundation

struct BranchPaneSnapshot: Codable {
    let projectPath: String
    let branch: String
    let selectedWorktreeID: String?
}

enum BranchPaneStore {
    private static let defaults = UserDefaults.standard
    private static let key = "BranchPaneSnapshots"

    static func save(_ panes: [BranchPane]) {
        let snapshots = panes.map { pane in
            BranchPaneSnapshot(
                projectPath: pane.project.path,
                branch: pane.branch,
                selectedWorktreeID: pane.selectedWorktreeID
            )
        }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }

    static func load() -> [BranchPaneSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        if let snapshots = try? decoder.decode([BranchPaneSnapshot].self, from: data) {
            return snapshots
        }
        return []
    }
}
