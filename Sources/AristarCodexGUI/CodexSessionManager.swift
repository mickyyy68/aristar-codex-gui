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
    let metadataRoot: URL
    let isManagedRoot: Bool

    init(projectRoot: URL, codexPath: String) {
        self.projectRoot = projectRoot
        self.codexPath = codexPath
        self.gitInfo = GitService.detectRepo(at: projectRoot)
        self.worktreesRoot = CodexSessionManager.makeWorktreesRoot(for: projectRoot)
        self.metadataRoot = CodexSessionManager.makeMetadataRoot(for: projectRoot)
        let managedBase = CodexSessionManager.managedBaseRoot().path
        self.isManagedRoot = projectRoot.path.hasPrefix(managedBase)

        try? FileManager.default.createDirectory(
            at: worktreesRoot,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? FileManager.default.createDirectory(
            at: metadataRoot,
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
            agentBranch: nil,
            shouldResume: false
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
            removeMetadata(for: session.workingDirectory)
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
            let metadata = WorktreeMetadata(
                originalBranch: branch,
                agentBranch: agentBranch,
                createdAt: Date(),
                displayName: worktreeName
            )
            persistMetadata(metadata, at: worktreeDir)
            let managed = ManagedWorktree(
                path: worktreeDir,
                originalBranch: branch,
                agentBranch: agentBranch,
                createdAt: metadata.createdAt,
                displayName: metadata.displayName ?? worktreeName,
                previewServices: metadata.previewServices
            )
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
                    createdAt: meta.createdAt,
                    displayName: meta.displayName ?? url.lastPathComponent,
                    previewServices: meta.previewServices
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
                createdAt: created,
                displayName: url.lastPathComponent,
                previewServices: []
            )
        }

        managedWorktrees = filtered
        return filtered
    }

    func loadAllManagedWorktrees() -> [ManagedWorktree] {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: worktreesRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        let all: [ManagedWorktree] = contents.compactMap { url in
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
                return nil
            }

            let metaURL = metadataURL(for: url)
            if let data = try? Data(contentsOf: metaURL),
               let meta = try? JSONDecoder().decode(WorktreeMetadata.self, from: data) {
                return ManagedWorktree(
                    path: url,
                    originalBranch: meta.originalBranch,
                    agentBranch: meta.agentBranch,
                    createdAt: meta.createdAt,
                    displayName: meta.displayName ?? url.lastPathComponent,
                    previewServices: meta.previewServices
                )
            }

            let name = url.lastPathComponent
            let parts = name.split(separator: "-")
            let isLegacyAgent = parts.first == "agent"
            let isManaged = name.hasPrefix(Self.managedPrefix)
            guard isLegacyAgent || isManaged else { return nil }

            let safeBranch = parts.count >= 3 ? parts[parts.count - 2] : Substring("")
            let inferredBranch = safeBranch.replacingOccurrences(of: "-", with: "/")
            let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let created = values?.creationDate ?? values?.contentModificationDate

            return ManagedWorktree(
                path: url,
                originalBranch: inferredBranch.isEmpty ? "" : inferredBranch,
                agentBranch: name,
                createdAt: created,
                displayName: url.lastPathComponent,
                previewServices: []
            )
        }

        managedWorktrees = all
        return all
    }

    func loadMetadata(for worktreeURL: URL) -> WorktreeMetadata? {
        let metaURL = metadataURL(for: worktreeURL)
        guard let data = try? Data(contentsOf: metaURL) else { return nil }
        return try? JSONDecoder().decode(WorktreeMetadata.self, from: data)
    }

    func updatePreviewServices(_ services: [PreviewServiceConfig], for worktree: ManagedWorktree) {
        var meta = loadMetadata(for: worktree.path) ?? WorktreeMetadata(
            originalBranch: worktree.originalBranch,
            agentBranch: worktree.agentBranch,
            createdAt: worktree.createdAt ?? Date(),
            displayName: worktree.displayName
        )
        meta.previewServices = services
        persistMetadata(meta, at: worktree.path)
    }

    func rename(_ worktree: ManagedWorktree, to newName: String) -> ManagedWorktree? {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastWorktreeError = "Name cannot be empty."
            return nil
        }
        var updated = worktree
        updated.displayName = trimmed

        var meta = loadMetadata(for: worktree.path) ?? WorktreeMetadata(
            originalBranch: worktree.originalBranch,
            agentBranch: worktree.agentBranch,
            createdAt: worktree.createdAt ?? Date(),
            displayName: worktree.displayName,
            previewServices: worktree.previewServices
        )
        meta.displayName = trimmed
        persistMetadata(meta, at: worktree.path)

        if let idx = managedWorktrees.firstIndex(where: { $0.id == worktree.id }) {
            managedWorktrees[idx] = updated
        }

        if let liveSession = session(for: worktree) {
            liveSession.title = trimmed
        }

        lastWorktreeError = nil
        return updated
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
            agentBranch: worktree.agentBranch,
            shouldResume: false
        )
        sessions.append(session)
        selectedSessionID = session.id
        return session
    }

    func resumeSession(for worktree: ManagedWorktree) -> CodexSession {
        if let existing = session(for: worktree) {
            selectedSessionID = existing.id
            return existing
        }

        let session = CodexSession(
            title: worktree.displayName,
            codexPath: codexPath,
            workingDirectory: worktree.path,
            originalBranch: worktree.originalBranch,
            agentBranch: worktree.agentBranch,
            shouldResume: true
        )
        sessions.append(session)
        selectedSessionID = session.id
        return session
    }

    func stopSession(for worktree: ManagedWorktree) {
        guard let existing = session(for: worktree) else { return }
        closeSession(existing, removeWorktree: false)
    }
    
    /// Stop all running sessions without removing worktrees (used on app termination)
    func stopAllSessions() {
        for session in sessions {
            session.stop()
        }
        sessions.removeAll()
        selectedSessionID = nil
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
        removeMetadata(for: worktree.path)
        print("[WorktreeDelete] Worktree \(worktree.path.lastPathComponent) removed")
        return true
    }

    private func persistMetadata(_ metadata: WorktreeMetadata, at worktreeURL: URL) {
        let url = metadataURL(for: worktreeURL)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: url)
        }
    }

    private func metadataURL(for worktreeURL: URL) -> URL {
        metadataRoot
            .appendingPathComponent(worktreeURL.lastPathComponent)
            .appendingPathExtension("json")
    }

    private func removeMetadata(for worktreeURL: URL) {
        let url = metadataURL(for: worktreeURL)
        try? FileManager.default.removeItem(at: url)
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

    static func metadataBaseRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aristar-codex-gui")
            .appendingPathComponent("metadata")
    }

    static func makeMetadataRoot(for projectRoot: URL) -> URL {
        let base = metadataBaseRoot()
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
