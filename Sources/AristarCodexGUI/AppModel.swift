import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var favorites: [ProjectRef] = []
    @Published var recents: [ProjectRef] = []
    @Published var selectedProject: ProjectRef?
    @Published var branchesForSelected: [String] = []
    @Published var selectedBranchName: String?
    @Published var branchPanes: [BranchPane] = []
    @Published var workingSet: [WorkingSetItem] = []
    @Published var selectedWorkingSetID: String?
    @Published var selectedTab: HubTab = .hubs
    @Published var restoreError: String?
    @Published var hubError: String?

    let codexAuth: CodexAuthManager
    private var managers: [String: CodexSessionManager] = [:]
    private var managerCancellables: [String: AnyCancellable] = [:]

    init() {
        self.codexAuth = CodexAuthManager()
        self.codexAuth.checkStatus()
        self.recents = ProjectListStore.loadRecents()
        self.favorites = ProjectListStore.loadFavorites()
        self.workingSet = WorkingSetStore.load()

        // Migration from legacy single recent
        if recents.isEmpty, let legacy = RecentProjectStore.load() {
            let ref = ProjectRef(url: legacy)
            recents = [ref]
            saveRecents()
        }

        restoreBranchPanes()
    }

    // MARK: - Project hub

    func selectProject(_ ref: ProjectRef) {
        selectedProject = ref
        addRecent(ref)
        branchesForSelected = loadBranches(for: ref)
        restoreError = nil
        hubError = nil
        selectedBranchName = nil
    }

    func addFavorite(_ ref: ProjectRef) {
        if !favorites.contains(ref) {
            favorites.append(ref)
            saveFavorites()
        }
    }

    func removeFavorite(_ ref: ProjectRef) {
        favorites.removeAll { $0 == ref }
        saveFavorites()
    }

    func addRecent(_ ref: ProjectRef) {
        recents.removeAll { $0 == ref }
        recents.insert(ref, at: 0)
        saveRecents()
    }

    func openBranchPane(for project: ProjectRef, branch: String) {
        if let idx = branchPanes.firstIndex(where: { $0.project == project && $0.branch == branch }) {
            branchPanes.remove(at: idx)
            if selectedBranchName == branch {
                selectedBranchName = branchPanes.first?.branch
            }
            persistBranchPanes()
            return
        }
        var pane = BranchPane(project: project, branch: branch)
        pane.worktrees = loadManagedWorktrees(for: branch, project: project)
        if let first = pane.worktrees.first {
            pane.selectedWorktreeID = first.id
        }
        branchPanes.append(pane)
        selectedBranchName = branch
        persistBranchPanes()
    }

    func closeBranchPane(_ pane: BranchPane) {
        branchPanes.removeAll { $0.id == pane.id }
        if selectedBranchName == pane.branch {
            selectedBranchName = branchPanes.first?.branch
        }
        persistBranchPanes()
    }

    func refreshPane(_ pane: BranchPane) {
        guard let idx = branchPanes.firstIndex(where: { $0.id == pane.id }) else { return }
        var updated = branchPanes[idx]
        updated.worktrees = loadManagedWorktrees(for: pane.branch, project: pane.project)
        if let selected = updated.selectedWorktreeID,
           !updated.worktrees.contains(where: { $0.id == selected }) {
            updated.selectedWorktreeID = updated.worktrees.first?.id
        }
        branchPanes[idx] = updated
        persistBranchPanes()
    }

    func selectWorktree(_ worktree: ManagedWorktree, in pane: BranchPane) {
        guard let idx = branchPanes.firstIndex(where: { $0.id == pane.id }) else { return }
        var updated = branchPanes[idx]
        updated.selectedWorktreeID = worktree.id
        branchPanes[idx] = updated
        persistBranchPanes()
    }

    func deleteWorktree(_ worktree: ManagedWorktree, in pane: BranchPane) {
        guard let manager = manager(for: pane.project.url) else { return }
        if !manager.deleteWorktree(worktree) {
            hubError = manager.lastWorktreeError
        }
        workingSet.removeAll { $0.id == worktree.id }
        WorkingSetStore.save(workingSet)
        refreshPane(pane)
        persistBranchPanes()
    }

    func createWorktree(in pane: BranchPane) {
        guard let manager = manager(for: pane.project.url) else { return }
        if manager.isManagedRoot {
            hubError = "Cannot create a worktree from another managed worktree (depth limit 1)."
            return
        }
        if manager.createManagedWorktree(branch: pane.branch) != nil {
            hubError = nil
            refreshPane(pane)
        } else {
            hubError = manager.lastWorktreeError
        }
    }

    // MARK: - Working set

    func addToWorkingSet(worktree: ManagedWorktree, project: ProjectRef) {
        let item = WorkingSetItem(worktree: worktree, project: project)
        if !workingSet.contains(item) {
            workingSet.append(item)
            WorkingSetStore.save(workingSet)
            selectedWorkingSetID = item.id
        }
    }

    func removeFromWorkingSet(_ item: WorkingSetItem) {
        workingSet.removeAll { $0.id == item.id }
        WorkingSetStore.save(workingSet)
        if selectedWorkingSetID == item.id {
            selectedWorkingSetID = workingSet.first?.id
        }
    }

    func isInWorkingSet(worktree: ManagedWorktree) -> Bool {
        workingSet.contains { $0.id == worktree.id }
    }

    func removeFromWorkingSet(worktree: ManagedWorktree, project: ProjectRef) {
        workingSet.removeAll { $0.id == worktree.id }
        WorkingSetStore.save(workingSet)
        if selectedWorkingSetID == worktree.id {
            selectedWorkingSetID = workingSet.first?.id
        }
    }

    // MARK: - Sessions

    func launch(worktree: ManagedWorktree, project: ProjectRef) -> CodexSession? {
        guard let manager = manager(for: project.url) else {
            log("[launch] No manager for project \(project.name)")
            return nil
        }
        let session = manager.startSession(for: worktree)
        log("[launch] Started session id=\(session.id) worktree=\(worktree.displayName) branch=\(worktree.originalBranch) project=\(project.name)")
        return session
    }

    func stop(worktree: ManagedWorktree, project: ProjectRef) {
        guard let manager = manager(for: project.url) else {
            log("[stop] No manager for project \(project.name)")
            return
        }
        manager.stopSession(for: worktree)
        log("[stop] Stopped session worktree=\(worktree.displayName) branch=\(worktree.originalBranch) project=\(project.name)")
    }

    func session(for worktree: ManagedWorktree, project: ProjectRef) -> CodexSession? {
        managers[project.url.path]?.session(for: worktree)
    }

    func isManagedRoot(_ project: ProjectRef) -> Bool {
        managers[project.url.path]?.isManagedRoot ?? false
    }

    func selectWorkingSet(item: WorkingSetItem?) {
        selectedWorkingSetID = item?.id
    }

    var selectedWorkingSetItem: WorkingSetItem? {
        workingSet.first { $0.id == selectedWorkingSetID }
    }

    func deleteWorktree(_ worktree: ManagedWorktree, project: ProjectRef) {
        guard let manager = manager(for: project.url) else { return }
        if !manager.deleteWorktree(worktree) {
            hubError = manager.lastWorktreeError
            log("[delete] Failed \(manager.lastWorktreeError ?? "unknown error") worktree=\(worktree.displayName)")
        }
        removeFromWorkingSet(worktree: worktree, project: project)
        branchPanes = branchPanes.map { pane in
            var updated = pane
            if pane.project == project {
                updated.worktrees.removeAll { $0.id == worktree.id }
            }
            return updated
        }
        log("[delete] Removed worktree=\(worktree.displayName) project=\(project.name)")
        persistBranchPanes()
    }

    // MARK: - Data helpers

    private func manager(for url: URL) -> CodexSessionManager? {
        if let existing = managers[url.path] {
            return existing
        }
        let manager = CodexSessionManager(projectRoot: url, codexPath: codexAuth.codexPath)
        if !manager.gitInfo.isGitRepo {
            hubError = "Not a git repository at \(url.lastPathComponent)."
            return nil
        }
        managerCancellables[url.path] = manager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
        managers[url.path] = manager
        return manager
    }

    private func loadBranches(for project: ProjectRef) -> [String] {
        guard let manager = manager(for: project.url) else { return [] }
        if manager.gitInfo.isGitRepo {
            switch GitService.listBranches(in: manager.gitInfo.repoRoot) {
            case .success(let list):
                return sanitizeBranches(list)
            case .failure:
                return []
            }
        }
        return []
    }

    private func sanitizeBranches(_ list: [String]) -> [String] {
        list.filter { branch in
            if branch.hasPrefix("agent-") { return false }
            if branch.hasPrefix(CodexSessionManager.managedPrefix) { return false }
            return true
        }
    }

    func worktree(from item: WorkingSetItem) -> ManagedWorktree? {
        let url = item.url
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }
        return ManagedWorktree(
            path: url,
            originalBranch: item.originalBranch,
            agentBranch: item.agentBranch,
            createdAt: nil
        )
    }

    private func loadManagedWorktrees(for branch: String, project: ProjectRef) -> [ManagedWorktree] {
        guard let manager = manager(for: project.url) else { return [] }
        let list = manager.loadManagedWorktrees(for: branch)
        return list.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    private func restoreBranchPanes() {
        let snapshots = BranchPaneStore.load()
        guard !snapshots.isEmpty else { return }

        var restored: [BranchPane] = []
        var skipped: [String] = []

        for snap in snapshots {
            let url = URL(fileURLWithPath: snap.projectPath)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                skipped.append("\(url.lastPathComponent) (missing)")
                continue
            }
            let ref = ProjectRef(url: url)
            guard let manager = manager(for: url), manager.gitInfo.isGitRepo else {
                skipped.append("\(ref.name) (not a git repo)")
                continue
            }

            var pane = BranchPane(project: ref, branch: snap.branch)
            pane.worktrees = loadManagedWorktrees(for: snap.branch, project: ref)
            if let savedID = snap.selectedWorktreeID,
               pane.worktrees.contains(where: { $0.id == savedID }) {
                pane.selectedWorktreeID = savedID
            } else {
                pane.selectedWorktreeID = pane.worktrees.first?.id
            }
            restored.append(pane)
        }

        branchPanes = restored
        selectedBranchName = branchPanes.first?.branch

        if !skipped.isEmpty {
            restoreError = "Skipped \(skipped.count) branch pane(s): \(skipped.joined(separator: ", "))"
        }
    }

    private func saveRecents() {
        ProjectListStore.saveRecents(recents)
    }

    private func saveFavorites() {
        ProjectListStore.saveFavorites(favorites)
    }

    private func persistBranchPanes() {
        BranchPaneStore.save(branchPanes)
    }

    // MARK: - Logging

    private func log(_ message: String) {
        print("[AppModel] \(message)")
    }
}
