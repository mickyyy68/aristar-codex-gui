import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var projectRoot: URL?
    @Published var sessionManager: CodexSessionManager?
    @Published var branches: [String] = []
    @Published var baseBranch: String?
    @Published var worktrees: [ManagedWorktree] = []
    @Published var selectedWorktreeID: String?
    @Published var worktreeError: String?
    @Published var recentProjectURL: URL?
    @Published var restoreError: String?

    let codexAuth: CodexAuthManager
    private var projectKey: String?

    init() {
        self.codexAuth = CodexAuthManager()
        self.codexAuth.checkStatus()
        self.recentProjectURL = RecentProjectStore.load()
    }

    func openProject(at url: URL) {
        projectRoot = url
        let manager = CodexSessionManager(projectRoot: url, codexPath: codexAuth.codexPath)
        sessionManager = manager
        projectKey = CodexSessionManager.projectKey(for: url)

        loadBranches(using: manager)
        hydrateStateFromStore()

        RecentProjectStore.save(url: url)
        recentProjectURL = url
        restoreError = nil
    }

    func restoreLastProjectIfAvailable() {
        if recentProjectURL == nil {
            recentProjectURL = RecentProjectStore.load()
        }

        guard sessionManager == nil,
              let url = recentProjectURL else { return }

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        let readable = FileManager.default.isReadableFile(atPath: url.path)

        guard exists, isDir.boolValue, readable else {
            restoreError = "Last project folder not found. Pick a folder to continue."
            RecentProjectStore.clear()
            recentProjectURL = nil
            return
        }

        openProject(at: url)
    }

    func selectBaseBranch(_ branch: String) {
        baseBranch = branch
        reloadWorktrees()
        persistProjectState()
    }

    func createWorktreeForBaseBranch() {
        guard let manager = sessionManager, let baseBranch else { return }
        if manager.isManagedRoot {
            worktreeError = "Cannot create a worktree from another managed worktree (depth limit 1). Open the main repository instead."
            return
        }
        if let newWT = manager.createManagedWorktree(branch: baseBranch) {
            worktreeError = nil
            reloadWorktrees(selecting: newWT)
        } else {
            worktreeError = manager.lastWorktreeError
        }
    }

    func reloadWorktrees(selecting newSelection: ManagedWorktree? = nil) {
        worktreeError = nil
        guard let manager = sessionManager, let baseBranch else {
            worktrees = []
            return
        }
        let list = manager.loadManagedWorktrees(for: baseBranch)
        worktrees = list.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }

        if let newSelection {
            selectedWorktreeID = newSelection.id
        } else if let selectedWorktreeID,
                  list.contains(where: { $0.id == selectedWorktreeID }) {
            // keep existing selection
        } else if let first = worktrees.first {
            selectedWorktreeID = first.id
        } else {
            selectedWorktreeID = nil
        }

        persistProjectState()
    }

    func selectWorktree(_ worktree: ManagedWorktree?) {
        selectedWorktreeID = worktree?.id
        persistProjectState()
    }

    var selectedWorktree: ManagedWorktree? {
        worktrees.first { $0.id == selectedWorktreeID }
    }

    func launchAgentForSelectedWorktree() -> CodexSession? {
        guard let manager = sessionManager, let selectedWorktree else { return nil }
        return manager.startSession(for: selectedWorktree)
    }

    func stopAgentForSelectedWorktree() {
        guard let manager = sessionManager, let selectedWorktree else { return }
        manager.stopSession(for: selectedWorktree)
    }

    func sessionForSelectedWorktree() -> CodexSession? {
        guard let manager = sessionManager, let selectedWorktree else { return nil }
        return manager.session(for: selectedWorktree)
    }

    func deleteSelectedWorktree() {
        guard let manager = sessionManager, let selectedWorktree else { return }
        if !manager.deleteWorktree(selectedWorktree) {
            worktreeError = manager.lastWorktreeError
        }
        reloadWorktrees()
    }

    func delete(worktree: ManagedWorktree) {
        guard let manager = sessionManager else { return }
        if !manager.deleteWorktree(worktree) {
            worktreeError = manager.lastWorktreeError
        }
        if selectedWorktreeID == worktree.id {
            selectedWorktreeID = nil
        }
        reloadWorktrees()
    }

    // MARK: - Private helpers

    private func loadBranches(using manager: CodexSessionManager) {
        if manager.gitInfo.isGitRepo {
            switch GitService.listBranches(in: manager.gitInfo.repoRoot) {
            case .success(let list):
                branches = sanitizeBranches(list)
            case .failure:
                branches = []
            }
        } else {
            branches = []
        }

        if baseBranch == nil {
            baseBranch = branches.first
        }
    }

    private func sanitizeBranches(_ list: [String]) -> [String] {
        list.filter { branch in
            if branch.hasPrefix("agent-") { return false }
            if branch.hasPrefix(CodexSessionManager.managedPrefix) { return false }
            return true
        }
    }

    private func hydrateStateFromStore() {
        guard let projectKey else {
            baseBranch = branches.first
            reloadWorktrees()
            return
        }

        let state = ProjectStateStore.load(for: projectKey)
        if let desiredBranch = state?.baseBranch, branches.contains(desiredBranch) {
            baseBranch = desiredBranch
        } else {
            baseBranch = branches.first
        }
        reloadWorktrees()

        if let targetPath = state?.selectedWorktreePath,
           let match = worktrees.first(where: { $0.path.path == targetPath }) {
            selectedWorktreeID = match.id
            worktreeError = nil
        } else if state?.selectedWorktreePath != nil {
            worktreeError = "Previously selected worktree is missing. Choose or create another."
        }
    }

    private func persistProjectState() {
        guard let projectKey else { return }
        let state = ProjectState(
            baseBranch: baseBranch,
            selectedWorktreePath: selectedWorktree?.path.path
        )
        ProjectStateStore.save(state, for: projectKey)
    }
}
