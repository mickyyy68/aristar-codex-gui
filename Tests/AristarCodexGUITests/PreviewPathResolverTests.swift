import XCTest
@testable import AristarCodexGUI

final class PreviewPathResolverTests: XCTestCase {
    func testResolvesEmptyToWorktreeRoot() {
        let root = "/tmp/worktree"
        XCTContext.runActivity(named: "Empty root uses worktree root") { _ in
            let resolved = PreviewPathResolver.resolve(rootPath: "", worktreePath: root)
            XCTAssertEqual(resolved, root, "Empty root should map to the worktree root path")
        }
    }

    func testResolvesRelativePaths() {
        let root = "/tmp/worktree"
        XCTContext.runActivity(named: "Relative paths are appended to worktree") { _ in
            XCTAssertEqual(
                PreviewPathResolver.resolve(rootPath: "frontend", worktreePath: root),
                "\(root)/frontend",
                "Plain relative path should be appended to worktree"
            )
            XCTAssertEqual(
                PreviewPathResolver.resolve(rootPath: "./frontend", worktreePath: root),
                "\(root)/frontend",
                "./relative path should drop the dot prefix and append to worktree"
            )
        }
    }

    func testPreservesAbsolutePath() {
        let root = "/tmp/worktree"
        let absolute = "/Users/test/custom"
        XCTContext.runActivity(named: "Absolute paths are preserved") { _ in
            XCTAssertEqual(
                PreviewPathResolver.resolve(rootPath: absolute, worktreePath: root),
                absolute,
                "Absolute paths should be returned unchanged"
            )
        }
    }
}
