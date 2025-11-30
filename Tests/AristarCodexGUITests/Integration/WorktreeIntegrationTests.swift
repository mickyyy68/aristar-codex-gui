import XCTest
@testable import AristarCodexGUI

@MainActor
final class WorktreeIntegrationTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try shell("git init", cwd: tempRoot)
        try shell("git config user.email \"test@example.com\"", cwd: tempRoot)
        try shell("git config user.name \"Test User\"", cwd: tempRoot)
        let readme = tempRoot.appendingPathComponent("README.md")
        try "hello".data(using: .utf8)?.write(to: readme)
        try shell("git add .", cwd: tempRoot)
        try shell("git commit -m \"init\"", cwd: tempRoot)
    }

    override func tearDownWithError() throws {
        if let tempRoot, FileManager.default.fileExists(atPath: tempRoot.path) {
            _ = try? shell("rm -rf \"\(tempRoot.path)\"")
        }
    }

    func testCreateAndDeleteManagedWorktree() throws {
        let manager = CodexSessionManager(projectRoot: tempRoot, codexPath: "/usr/bin/true")
        XCTAssertTrue(manager.gitInfo.isGitRepo)

        XCTContext.runActivity(named: "Create managed worktree from main") { _ in
            let branch = "main"
            guard let worktree = manager.createManagedWorktree(branch: branch) else {
                XCTFail("Failed to create worktree: \(manager.lastWorktreeError ?? "unknown")")
                return
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: worktree.path.path), "Worktree directory should exist")
            XCTAssertEqual(worktree.originalBranch, branch)

            XCTContext.runActivity(named: "Delete managed worktree and branch") { _ in
                let removed = manager.deleteWorktree(worktree)
                XCTAssertTrue(removed, "deleteWorktree should return true")
                XCTAssertFalse(FileManager.default.fileExists(atPath: worktree.path.path), "Worktree directory should be removed")
            }
        }
    }

    func testRenameManagedWorktreePersistsDisplayName() throws {
        let manager = CodexSessionManager(projectRoot: tempRoot, codexPath: "/usr/bin/true")
        let branch = "main"

        guard let worktree = manager.createManagedWorktree(branch: branch) else {
            XCTFail("Failed to create worktree: \(manager.lastWorktreeError ?? "unknown")")
            return
        }
        defer { _ = manager.deleteWorktree(worktree) }

        let alias = "Renamed Worktree"
        guard let renamed = manager.rename(worktree, to: alias) else {
            XCTFail("Rename failed: \(manager.lastWorktreeError ?? "unknown error")")
            return
        }

        XCTAssertEqual(renamed.displayName, alias)
        XCTAssertEqual(manager.loadMetadata(for: worktree.path)?.displayName, alias)

        let reloaded = manager.loadManagedWorktrees(for: branch)
        let matched = reloaded.first { $0.id == worktree.id }
        XCTAssertEqual(matched?.displayName, alias)
        XCTAssertEqual(matched?.agentBranch, worktree.agentBranch)
    }
}

private extension WorktreeIntegrationTests {
    @discardableResult
    func shell(_ command: String, cwd: URL? = nil) throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.currentDirectoryURL = cwd

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            throw NSError(domain: "ShellError", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
        }
        return output
    }
}
