import Foundation

struct GitRepoInfo {
    let repoRoot: URL
    let isGitRepo: Bool
}

enum GitError: Error {
    case commandFailed(String)
}

enum GitService {
    static func detectRepo(at url: URL) -> GitRepoInfo {
        switch runGit(["rev-parse", "--show-toplevel"], in: url) {
        case .success(let output):
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return GitRepoInfo(repoRoot: URL(fileURLWithPath: path), isGitRepo: true)
        case .failure:
            return GitRepoInfo(repoRoot: url, isGitRepo: false)
        }
    }

    static func listBranches(in repoRoot: URL) -> Result<[String], GitError> {
        switch runGit(["for-each-ref", "--format=%(refname:short)", "refs/heads"], in: repoRoot) {
        case .success(let output):
            let branches = output
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return .success(branches)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func createWorktree(
        repoRoot: URL,
        branch: String,
        startPoint: String? = nil,
        worktreePath: URL
    ) -> Result<Void, GitError> {

        try? FileManager.default.createDirectory(
            at: worktreePath.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var args: [String]
        if let base = startPoint {
            args = ["worktree", "add", "-b", branch, worktreePath.path, base]
        } else {
            args = ["worktree", "add", worktreePath.path, branch]
        }

        switch runGit(args, in: repoRoot) {
        case .success:
            return .success(())
        case .failure(let err):
            return .failure(err)
        }
    }

    static func removeWorktree(repoRoot: URL, worktreePath: URL) -> Result<Void, GitError> {
        switch runGit(["worktree", "remove", worktreePath.path], in: repoRoot) {
        case .success:
            return .success(())
        case .failure(let err):
            return .failure(err)
        }
    }

    static func deleteBranch(repoRoot: URL, branch: String) -> Result<Void, GitError> {
        switch runGit(["branch", "-D", branch], in: repoRoot) {
        case .success:
            return .success(())
        case .failure(let err):
            return .failure(err)
        }
    }

    private static func runGit(_ args: [String], in dir: URL) -> Result<String, GitError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure(.commandFailed("Failed to run git: \(error.localizedDescription)"))
        }

        process.waitUntilExit()
        let code = process.terminationStatus

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if code == 0 {
            let output = String(data: outData, encoding: .utf8) ?? ""
            return .success(output)
        } else {
            let msg = String(data: errData, encoding: .utf8) ?? "Unknown git error"
            return .failure(.commandFailed(msg))
        }
    }
}
