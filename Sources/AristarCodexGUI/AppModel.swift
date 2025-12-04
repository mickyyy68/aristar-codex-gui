import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    // MARK: - Project State (Single Project Focus)
    @Published var currentProject: ProjectRef?
    @Published var favorites: [ProjectRef] = []
    @Published var recents: [ProjectRef] = []
    
    // MARK: - Terminal Panel State
    @Published var openTerminalTabs: [String] = []  // worktree IDs
    @Published var activeTerminalID: String?
    
    // MARK: - UI State
    @Published var hubError: String?
    @Published var previewError: String?
    @Published private(set) var previewSessions: [String: [UUID: PreviewServiceSession]] = [:]
    
    // MARK: - Services
    let codexAuth: CodexAuthManager
    private var managers: [String: CodexSessionManager] = [:]
    private var managerCancellables: [String: AnyCancellable] = [:] 
    private var previewSessionCancellables: [UUID: AnyCancellable] = [:]
    
    // MARK: - Computed Properties
    
    var hasOpenTerminals: Bool {
        !openTerminalTabs.isEmpty
    }
    
    var worktreesForCurrentProject: [ManagedWorktree] {
        guard let project = currentProject,
              let manager = manager(for: project.url) else { return [] }
        return manager.loadAllManagedWorktrees()
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    var branchesForCurrentProject: [String] {
        guard let project = currentProject else { return [] }
        return loadBranches(for: project)
    }
    
    var isManagedRoot: Bool {
        guard let project = currentProject else { return false }
        return managers[project.url.path]?.isManagedRoot ?? false
    }
    
    // MARK: - Initialization
    
    init() {
        self.codexAuth = CodexAuthManager()
        self.codexAuth.checkStatus()
        self.recents = ProjectListStore.loadRecents()
        self.favorites = ProjectListStore.loadFavorites()
        
        // Migration from legacy single recent
        if recents.isEmpty, let legacy = RecentProjectStore.load() {
            let ref = ProjectRef(url: legacy)
            recents = [ref]
            saveRecents()
        }
        // Ensure favorites are not duplicated into recents on load.
        recents.removeAll { favorites.contains($0) }
        saveRecents()
        
        // Restore last opened project
        if let savedProject = TerminalPanelStore.loadCurrentProject() {
            openProject(savedProject, recordRecent: false)
        }
        
        // Restore terminal tabs
        openTerminalTabs = TerminalPanelStore.loadOpenTabs().filter { id in
            worktreesForCurrentProject.contains { $0.id == id }
        }
        activeTerminalID = TerminalPanelStore.loadActiveTab()
        if let active = activeTerminalID, !openTerminalTabs.contains(active) {
            activeTerminalID = openTerminalTabs.first
        }
    }
    
    // MARK: - Project Management
    
    func openProject(_ ref: ProjectRef, recordRecent: Bool = true) {
        // Validate project exists and is a git repo
        guard let manager = manager(for: ref.url), manager.gitInfo.isGitRepo else {
            hubError = "Not a git repository at \(ref.name)."
            return
        }
        
        currentProject = ref
        hubError = nil
        
        // Close terminals from previous project
        openTerminalTabs = []
        activeTerminalID = nil
        
        if recordRecent {
            if !favorites.contains(ref) {
                addRecent(ref)
            }
        }
        
        TerminalPanelStore.saveCurrentProject(ref)
        persistTerminalState()
    }
    
    func addFavorite(_ ref: ProjectRef) {
        if !favorites.contains(ref) {
            favorites.append(ref)
            recents.removeAll { $0 == ref }
            saveFavorites()
            saveRecents()
        }
    }
    
    func removeFavorite(_ ref: ProjectRef) {
        favorites.removeAll { $0 == ref }
        saveFavorites()
        addRecent(ref)
    }
    
    func addRecent(_ ref: ProjectRef) {
        recents.removeAll { $0 == ref }
        recents.insert(ref, at: 0)
        // Keep only last 5 recents
        if recents.count > 5 {
            recents = Array(recents.prefix(5))
        }
        saveRecents()
    }
    
    func removeProjectCompletely(_ ref: ProjectRef) {
        favorites.removeAll { $0 == ref }
        recents.removeAll { $0 == ref }
        saveFavorites()
        saveRecents()
        
        if currentProject == ref {
            currentProject = nil
            openTerminalTabs = []
            activeTerminalID = nil
            TerminalPanelStore.saveCurrentProject(nil)
            persistTerminalState()
        }
        
        guard let manager = manager(for: ref.url) else { return }
        let allManaged = manager.loadAllManagedWorktrees()
        for wt in allManaged {
            stopPreview(for: wt)
            _ = manager.deleteWorktree(wt)
        }
    }
    
    // MARK: - Worktree Management
    
    func createWorktree(fromBranch branch: String) {
        guard let project = currentProject,
              let manager = manager(for: project.url) else { return }
        
        if manager.isManagedRoot {
            hubError = "Cannot create a worktree from another managed worktree (depth limit 1)."
            return
        }
        
        if let worktree = manager.createManagedWorktree(branch: branch) {
            hubError = nil
            // Auto-start the agent and open terminal
            startAgent(for: worktree)
        } else {
            hubError = manager.lastWorktreeError
        }
    }
    
    func deleteWorktree(_ worktree: ManagedWorktree) {
        guard let project = currentProject,
              let manager = manager(for: project.url) else { return }
        
        // Stop any running session
        stopAgent(for: worktree)
        stopPreview(for: worktree)
        
        // Close terminal tab
        closeTerminal(worktree.id)
        
        // Delete the worktree
        if !manager.deleteWorktree(worktree) {
            hubError = manager.lastWorktreeError
            log("[delete] Failed \(manager.lastWorktreeError ?? "unknown error") worktree=\(worktree.displayName)")
        } else {
            log("[delete] Removed worktree=\(worktree.displayName) project=\(project.name)")
        }
    }
    
    @discardableResult
    func renameWorktree(_ worktree: ManagedWorktree, to newName: String) -> Bool {
        guard let project = currentProject,
              let manager = manager(for: project.url) else { return false }
        
        guard manager.rename(worktree, to: newName) != nil else {
            hubError = manager.lastWorktreeError
            return false
        }
        hubError = nil
        return true
    }
    
    // MARK: - Terminal Management
    
    func openTerminal(for worktree: ManagedWorktree) {
        if !openTerminalTabs.contains(worktree.id) {
            openTerminalTabs.append(worktree.id)
        }
        activeTerminalID = worktree.id
        persistTerminalState()
    }
    
    func closeTerminal(_ worktreeID: String) {
        openTerminalTabs.removeAll { $0 == worktreeID }
        if activeTerminalID == worktreeID {
            activeTerminalID = openTerminalTabs.first
        }
        persistTerminalState()
    }
    
    func closeAllTerminals() {
        openTerminalTabs = []
        activeTerminalID = nil
        persistTerminalState()
    }
    
    func worktreeByID(_ id: String) -> ManagedWorktree? {
        worktreesForCurrentProject.first { $0.id == id }
    }
    
    // MARK: - Agent Sessions
    
    func startAgent(for worktree: ManagedWorktree) {
        guard let project = currentProject,
              let manager = manager(for: project.url) else {
            log("[start] No project or manager")
            return
        }
        
        let session = manager.startSession(for: worktree)
        log("[start] Started session id=\(session.id) worktree=\(worktree.displayName)")
        
        // Open terminal
        openTerminal(for: worktree)
    }
    
    func stopAgent(for worktree: ManagedWorktree) {
        guard let project = currentProject,
              let manager = manager(for: project.url) else {
            log("[stop] No project or manager")
            return
        }
        
        manager.stopSession(for: worktree)
        log("[stop] Stopped session worktree=\(worktree.displayName)")
        
        // Close terminal tab
        closeTerminal(worktree.id)
    }
    
    func resumeAgent(for worktree: ManagedWorktree) {
        guard let project = currentProject,
              let manager = manager(for: project.url) else {
            log("[resume] No project or manager")
            return
        }
        
        let session = manager.resumeSession(for: worktree)
        log("[resume] Resumed session id=\(session.id) worktree=\(worktree.displayName)")
    }
    
    func isSessionRunning(for worktree: ManagedWorktree) -> Bool {
        guard let project = currentProject else { return false }
        return managers[project.url.path]?.session(for: worktree) != nil
    }
    
    func sessionForWorktree(_ worktree: ManagedWorktree) -> CodexSession? {
        guard let project = currentProject else { return nil }
        return managers[project.url.path]?.session(for: worktree)
    }
    
    // MARK: - Preview Services
    
    func previewConfigs(for worktree: ManagedWorktree, project: ProjectRef) -> [PreviewServiceConfig] {
        guard let manager = manager(for: project.url) else { return worktree.previewServices }
        if let meta = manager.loadMetadata(for: worktree.path) {
            return meta.previewServices
        }
        return worktree.previewServices
    }
    
    func savePreviewConfigs(_ services: [PreviewServiceConfig], for worktree: ManagedWorktree, project: ProjectRef) -> ManagedWorktree {
        guard let manager = manager(for: project.url) else { return worktree }
        manager.updatePreviewServices(services, for: worktree)
        var updated = worktree
        updated.previewServices = services
        return updated
    }
    
    func startPreview(for worktree: ManagedWorktree, services: [PreviewServiceConfig]) {
        previewError = nil
        let enabled = services.filter { $0.enabled }
        guard !enabled.isEmpty else {
            previewError = "Add and enable at least one service to start a preview."
            return
        }
        
        for service in enabled {
            _ = startPreviewService(service, worktree: worktree)
        }
    }
    
    func startPreviewService(_ service: PreviewServiceConfig, worktree: ManagedWorktree) -> PreviewServiceSession? {
        previewError = nil
        let trimmed = service.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            previewError = "Command is required for \(service.name.isEmpty ? "a service" : service.name)."
            return nil
        }
        
        let root = resolvedRootPath(service, worktree: worktree)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
            previewError = "Root path for \(service.name.isEmpty ? "service" : service.name) is not a folder."
            return nil
        }
        
        if let existing = previewSessions[worktree.id]?[service.id], existing.isRunning {
            observePreviewSession(existing)
            return existing
        }
        
        let session = PreviewServiceSession(
            serviceID: service.id,
            name: service.name.isEmpty ? "Service" : service.name,
            command: trimmed,
            workingDirectory: URL(fileURLWithPath: root),
            envText: service.envText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : service.envText
        )
        session.onExit = { [weak self] in
            Task { @MainActor in
                self?.removePreviewSession(worktreeID: worktree.id, serviceID: service.id)
            }
        }
        observePreviewSession(session)
        previewSessions[worktree.id, default: [:]][service.id] = session
        return session
    }
    
    func stopPreviewService(_ serviceID: UUID, worktree: ManagedWorktree) {
        if let session = previewSessions[worktree.id]?[serviceID] {
            session.stop()
        }
        previewError = nil
        removePreviewSession(worktreeID: worktree.id, serviceID: serviceID)
    }
    
    func stopPreview(for worktree: ManagedWorktree) {
        if let sessions = previewSessions[worktree.id]?.values {
            sessions.forEach { session in
                session.stop()
                previewSessionCancellables.removeValue(forKey: session.id)
            }
        }
        previewError = nil
        previewSessions.removeValue(forKey: worktree.id)
    }
    
    func isPreviewRunning(for worktree: ManagedWorktree) -> Bool {
        previewSessions[worktree.id]?.values.contains { $0.isRunning } ?? false
    }
    
    func isPreviewRunning(serviceID: UUID, worktree: ManagedWorktree) -> Bool {
        previewSessions[worktree.id]?[serviceID]?.isRunning ?? false
    }
    
    // MARK: - Private Helpers
    
    private func manager(for url: URL) -> CodexSessionManager? {
        if let existing = managers[url.path] {
            return existing
        }
        let manager = CodexSessionManager(projectRoot: url, codexPath: codexAuth.codexPath)
        if !manager.gitInfo.isGitRepo {
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
    
    private func resolvedRootPath(_ service: PreviewServiceConfig, worktree: ManagedWorktree) -> String {
        PreviewPathResolver.resolve(rootPath: service.rootPath, worktreePath: worktree.path.path)
    }
    
    private func observePreviewSession(_ session: PreviewServiceSession) {
        guard previewSessionCancellables[session.id] == nil else { return }
        previewSessionCancellables[session.id] = session.$isRunning
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    private func removePreviewSession(worktreeID: String, serviceID: UUID) {
        if let session = previewSessions[worktreeID]?[serviceID] {
            previewSessionCancellables.removeValue(forKey: session.id)
        }
        previewSessions[worktreeID]?.removeValue(forKey: serviceID)
        if previewSessions[worktreeID]?.isEmpty == true {
            previewSessions.removeValue(forKey: worktreeID)
        }
    }
    
    private func saveRecents() {
        ProjectListStore.saveRecents(recents)
    }
    
    private func saveFavorites() {
        ProjectListStore.saveFavorites(favorites)
    }
    
    private func persistTerminalState() {
        TerminalPanelStore.saveOpenTabs(openTerminalTabs)
        TerminalPanelStore.saveActiveTab(activeTerminalID)
    }
    
    private func log(_ message: String) {
        print("[AppModel] \(message)")
    }
}
