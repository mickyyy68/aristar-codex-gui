import Foundation
import Combine
import CryptoKit

@MainActor
final class CodexSessionManager: ObservableObject {
    static let managedPrefix = "aristar-wt-"

    @Published var sessions: [CodexSession] = []
    @Published var selectedSessionID: UUID?
    @Published var lastWorktreeError: String?
    @Published var managedWorktrees: [ManagedWorktree] = []

    let projectRoot: URL
    let gitInfo: GitRepoInfo
    let codexPath: String
    let worktreesRoot: URL
    let isManagedRoot: Bool

    init(projectRoot: URL, codexPath: String) {
        self.projectRoot = projectRoot
        self.codexPath = codexPath
        self.gitInfo = GitService.detectRepo(at: projectRoot)
        self.worktreesRoot = CodexSessionManager.makeWorktreesRoot(for: projectRoot)
        let managedBase = CodexSessionManager.managedBaseRoot().path
        self.isManagedRoot = projectRoot.path.hasPrefix(managedBase)

        try? FileManager.default.createDirectory(
            at: worktreesRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    func addPlainSession() {
        let num = sessions.count + 1
        let session = CodexSession(
            title: "Agent \(num)",
            codexPath: codexPath,
            workingDirectory: projectRoot,
            originalBranch: nil,
            agentBranch: nil
        )
        sessions.append(session)
        selectedSessionID = session.id
    }

    func closeSession(_ session: CodexSession, removeWorktree: Bool = false) {
        session.stop()
        sessions.removeAll { $0.id == session.id }

        if removeWorktree,
           session.workingDirectory.path.hasPrefix(worktreesRoot.path),
           gitInfo.isGitRepo {
            var wtResult = GitService.removeWorktree(
                repoRoot: gitInfo.repoRoot,
                worktreePath: session.workingDirectory
            )
            if case .failure(let err) = wtResult,
               case .commandFailed(let msg) = err,
               msg.contains("contains modified or untracked files") {
                wtResult = GitService.removeWorktree(
                    repoRoot: gitInfo.repoRoot,
                    worktreePath: session.workingDirectory,
                    force: true
                )
            }
            if let branch = session.agentBranch {
                _ = GitService.deleteBranch(repoRoot: gitInfo.repoRoot, branch: branch)
            }
            if case .failure(let err) = wtResult {
                lastWorktreeError = "Failed to delete worktree: \(err)"
            }
        }

        if sessions.isEmpty {
            selectedSessionID = nil
        } else {
            selectedSessionID = sessions.first?.id
        }
    }

    var selectedSession: CodexSession? {
        sessions.first { $0.id == selectedSessionID }
    }

    func deleteBranch(for session: CodexSession) {
        closeSession(session, removeWorktree: true)
    }

    func createManagedWorktree(branch: String, startPoint: String? = nil) -> ManagedWorktree? {
        guard gitInfo.isGitRepo else {
            lastWorktreeError = "Not a git repository."
            return nil
        }

        lastWorktreeError = nil

        let safeBranch = branch.replacingOccurrences(of: "/", with: "-")
        let suffix = UUID().uuidString.prefix(8)
        let worktreeName = "\(Self.managedPrefix)\(safeBranch)-\(suffix)"
        let worktreeDir = worktreesRoot.appendingPathComponent(worktreeName)

        let agentBranch = worktreeName
        let start = startPoint ?? branch

        switch GitService.createWorktree(
            repoRoot: gitInfo.repoRoot,
            branch: agentBranch,
            startPoint: start,
            worktreePath: worktreeDir
        ) {
        case .success:
            let metadata = WorktreeMetadata(originalBranch: branch, agentBranch: agentBranch, createdAt: Date())
            persistMetadata(metadata, at: worktreeDir)
            let managed = ManagedWorktree(path: worktreeDir, originalBranch: branch, agentBranch: agentBranch, createdAt: metadata.createdAt)
            managedWorktrees.append(managed)
            return managed
        case .failure(let err):
            let message: String
            switch err {
            case .commandFailed(let msg):
                message = msg
            }
            lastWorktreeError = "Failed to create worktree: \(message)"
            return nil
        }
    }

    func loadManagedWorktrees(for branch: String) -> [ManagedWorktree] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: worktreesRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        let filtered: [ManagedWorktree] = contents.compactMap { url in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }

            let metaURL = metadataURL(for: url)
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONDecoder().decode(WorktreeMetadata.self, from: data),
               meta.originalBranch == branch {
                return ManagedWorktree(
                    path: url,
                    originalBranch: meta.originalBranch,
                    agentBranch: meta.agentBranch,
                    createdAt: meta.createdAt
                )
            }

            // Fallback for older worktrees without metadata: infer from name if possible.
            let name = url.lastPathComponent
            let parts = name.split(separator: "-")
            let isLegacyAgent = parts.first == "agent"
            let isManaged = name.hasPrefix(Self.managedPrefix)
            guard isLegacyAgent || isManaged else { return nil }

            let safeBranch = parts.count >= 3 ? parts[parts.count - 2] : Substring("")
            let inferredBranch = safeBranch.replacingOccurrences(of: "-", with: "/")
            guard inferredBranch == branch || inferredBranch.isEmpty else { return nil }

            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = values?.creationDate ?? values?.contentModificationDate

            return ManagedWorktree(
                path: url,
                originalBranch: inferredBranch.isEmpty ? branch : inferredBranch,
                agentBranch: name,
                createdAt: created
            )
        }

        managedWorktrees = filtered
        return filtered
    }

    func startSession(for worktree: ManagedWorktree) -> CodexSession {
        if let existing = session(for: worktree) {
            selectedSessionID = existing.id
            return existing
        }

        let session = CodexSession(
            title: worktree.displayName,
            codexPath: codexPath,
            workingDirectory: worktree.path,
            originalBranch: worktree.originalBranch,
            agentBranch: worktree.agentBranch
        )
        sessions.append(session)
        selectedSessionID = session.id
        return session
    }

    func stopSession(for worktree: ManagedWorktree) {
        guard let existing = session(for: worktree) else { return }
        closeSession(existing, removeWorktree: false)
    }

    func session(for worktree: ManagedWorktree) -> CodexSession? {
        sessions.first { $0.workingDirectory == worktree.path }
    }

    func deleteWorktree(_ worktree: ManagedWorktree) -> Bool {
        print("[WorktreeDelete] Requested delete for \(worktree.path.path) branch=\(worktree.agentBranch)")
        var success = true
        if let existing = session(for: worktree) {
            closeSession(existing, removeWorktree: true)
        } else {
            success = removeWorktreeOnDisk(worktree)
        }
        managedWorktrees.removeAll { $0.id == worktree.id }
        print("[WorktreeDelete] Finished delete for \(worktree.path.path) success=\(success) error=\(lastWorktreeError ?? "none")")
        return success
    }

    private func removeWorktreeOnDisk(_ worktree: ManagedWorktree) -> Bool {
        guard worktree.path.path.hasPrefix(worktreesRoot.path) else { return false }
        var wtResult = GitService.removeWorktree(repoRoot: gitInfo.repoRoot, worktreePath: worktree.path)
        if case .failure(let err) = wtResult,
           case .commandFailed(let msg) = err,
           msg.contains("contains modified or untracked files") {
            print("[WorktreeDelete] Retrying delete with force for \(worktree.path.lastPathComponent)")
            wtResult = GitService.removeWorktree(repoRoot: gitInfo.repoRoot, worktreePath: worktree.path, force: true)
        }

        let brResult = GitService.deleteBranch(repoRoot: gitInfo.repoRoot, branch: worktree.agentBranch)

        if case .failure(let err) = wtResult {
            lastWorktreeError = "Failed to delete worktree: \(err)"
            print("[WorktreeDelete] Git worktree remove failed: \(err)")
            return false
        }
        if case .failure(let err) = brResult {
            lastWorktreeError = "Deleted worktree, but branch removal failed: \(err)"
            print("[WorktreeDelete] Branch delete failed: \(err)")
            return false
        }
        print("[WorktreeDelete] Worktree \(worktree.path.lastPathComponent) removed")
        return true
    }

    private func persistMetadata(_ metadata: WorktreeMetadata, at worktreeURL: URL) {
        let url = metadataURL(for: worktreeURL)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: url)
        }
    }

    private func metadataURL(for worktreeURL: URL) -> URL {
        worktreeURL.appendingPathComponent(".codex-worktree.json")
    }

    static func managedBaseRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aristar-codex-gui")
            .appendingPathComponent("worktrees")
    }

    static func makeWorktreesRoot(for projectRoot: URL) -> URL {
        let base = managedBaseRoot()
        let key = projectKey(for: projectRoot)
        return base.appendingPathComponent(key)
    }

    static func projectKey(for projectRoot: URL) -> String {
        let name = projectRoot.lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let data = Data(projectRoot.path.utf8)
        let hash = SHA256.hash(data: data)
        let hashHex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "\(name)-\(hashHex.prefix(8))"
    }
}
