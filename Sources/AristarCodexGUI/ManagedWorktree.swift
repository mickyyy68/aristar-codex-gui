import Foundation

struct WorktreeMetadata: Codable {
    let originalBranch: String
    let agentBranch: String
    let createdAt: Date
}

struct ManagedWorktree: Identifiable, Equatable {
    let path: URL
    let originalBranch: String
    let agentBranch: String
    let createdAt: Date?

    var id: String { path.path }
    var displayName: String { path.lastPathComponent }
}
