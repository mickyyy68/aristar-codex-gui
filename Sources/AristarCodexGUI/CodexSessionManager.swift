import Foundation
import Combine
import CryptoKit

@MainActor
final class CodexSessionManager: ObservableObject {
    @Published var sessions: [CodexSession] = []
    @Published var selectedSessionID: UUID?
    @Published var lastWorktreeError: String?

    let projectRoot: URL
    let gitInfo: GitRepoInfo
    let codexPath: String
    private let worktreesRoot: URL

    init(projectRoot: URL, codexPath: String) {
        self.projectRoot = projectRoot
        self.codexPath = codexPath
        self.gitInfo = GitService.detectRepo(at: projectRoot)
        self.worktreesRoot = CodexSessionManager.makeWorktreesRoot(for: projectRoot)

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

    func addWorktreeSession(branch: String, startPoint: String? = nil) {
        guard gitInfo.isGitRepo else {
            addPlainSession()
            return
        }

        lastWorktreeError = nil

        let safeBranch = branch.replacingOccurrences(of: "/", with: "-")
        let num = sessions.count + 1
        let suffix = UUID().uuidString.prefix(8)
        let worktreeDir = worktreesRoot.appendingPathComponent("agent-\(num)-\(safeBranch)-\(suffix)")

        // Git worktrees cannot check out the same branch in multiple worktrees. Create a dedicated
        // agent branch from the selected start point to avoid collisions.
        let agentBranch = "agent-\(num)-\(safeBranch)-\(suffix)"
        let start = startPoint ?? branch

        switch GitService.createWorktree(
            repoRoot: gitInfo.repoRoot,
            branch: agentBranch,
            startPoint: start,
            worktreePath: worktreeDir
        ) {
        case .success:
            let session = CodexSession(
                title: "Agent \(num) [\(branch)]",
                codexPath: codexPath,
                workingDirectory: worktreeDir,
                originalBranch: branch,
                agentBranch: agentBranch
            )
            sessions.append(session)
            selectedSessionID = session.id
        case .failure(let err):
            let message: String
            switch err {
            case .commandFailed(let msg):
                message = msg
            }
            lastWorktreeError = "Failed to create worktree: \(message)"
            // Fall back to plain session so the user still gets an agent.
            addPlainSession()
        }
    }

    func closeSession(_ session: CodexSession) {
        session.stop()
        sessions.removeAll { $0.id == session.id }

        if session.workingDirectory.path.hasPrefix(worktreesRoot.path),
           gitInfo.isGitRepo {
            _ = GitService.removeWorktree(
                repoRoot: gitInfo.repoRoot,
                worktreePath: session.workingDirectory
            )
            if let branch = session.agentBranch {
                _ = GitService.deleteBranch(repoRoot: gitInfo.repoRoot, branch: branch)
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
        closeSession(session)
    }

    private static func makeWorktreesRoot(for projectRoot: URL) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let base = home
            .appendingPathComponent(".aristar-codex-gui")
            .appendingPathComponent("worktrees")

        let key = projectKey(for: projectRoot)
        return base.appendingPathComponent(key)
    }

    private static func projectKey(for projectRoot: URL) -> String {
        let name = projectRoot.lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let data = Data(projectRoot.path.utf8)
        let hash = SHA256.hash(data: data)
        let hashHex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return "\(name)-\(hashHex.prefix(8))"
    }
}
