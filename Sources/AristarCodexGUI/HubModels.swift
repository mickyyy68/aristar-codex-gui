import Foundation

struct ProjectRef: Identifiable, Equatable, Codable {
    let id: String
    let path: String
    let name: String

    init(url: URL) {
        self.path = url.path
        self.name = url.lastPathComponent
        self.id = url.path
    }

    var url: URL { URL(fileURLWithPath: path) }
}

struct BranchPane: Identifiable, Equatable {
    let id: UUID
    let project: ProjectRef
    let branch: String
    var worktrees: [ManagedWorktree] = []
    var selectedWorktreeID: String?
    var error: String?

    init(project: ProjectRef, branch: String, worktrees: [ManagedWorktree] = [], selectedWorktreeID: String? = nil, error: String? = nil) {
        self.id = UUID()
        self.project = project
        self.branch = branch
        self.worktrees = worktrees
        self.selectedWorktreeID = selectedWorktreeID
        self.error = error
    }
}

struct WorkingSetItem: Identifiable, Codable, Equatable {
    let id: String
    let project: ProjectRef
    let worktreePath: String
    let originalBranch: String
    let agentBranch: String
    var displayName: String

    init(worktree: ManagedWorktree, project: ProjectRef) {
        self.id = worktree.path.path
        self.project = project
        self.worktreePath = worktree.path.path
        self.originalBranch = worktree.originalBranch
        self.agentBranch = worktree.agentBranch
        self.displayName = worktree.displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        project = try container.decode(ProjectRef.self, forKey: .project)
        worktreePath = try container.decode(String.self, forKey: .worktreePath)
        originalBranch = try container.decode(String.self, forKey: .originalBranch)
        agentBranch = try container.decode(String.self, forKey: .agentBranch)
        let slug = URL(fileURLWithPath: worktreePath).lastPathComponent
        let rawName = try container.decodeIfPresent(String.self, forKey: .displayName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let rawName, !rawName.isEmpty {
            displayName = rawName
        } else {
            displayName = slug
        }
    }

    static func == (lhs: WorkingSetItem, rhs: WorkingSetItem) -> Bool {
        lhs.id == rhs.id
    }

    var url: URL { URL(fileURLWithPath: worktreePath) }
}

enum HubTab: Int, Hashable {
    case hubs
    case workingSet
}
