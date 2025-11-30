import XCTest
@testable import AristarCodexGUI

final class WorkingSetItemTests: XCTestCase {
    func testDecodesLegacyWithoutDisplayName() throws {
        let json = """
        {
            "id": "/tmp/project/.aristar/wt-one",
            "project": { "id": "/tmp/project", "path": "/tmp/project", "name": "project" },
            "worktreePath": "/tmp/project/.aristar/wt-one",
            "originalBranch": "main",
            "agentBranch": "aristar-wt-main-1234"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(WorkingSetItem.self, from: json)
        XCTAssertEqual(item.displayName, "wt-one")
    }

    func testEqualityIgnoresDisplayName() {
        let project = ProjectRef(url: URL(fileURLWithPath: "/tmp/project"))
        let worktreeURL = URL(fileURLWithPath: "/tmp/project/.aristar/wt-one")
        let worktree = ManagedWorktree(
            path: worktreeURL,
            originalBranch: "main",
            agentBranch: "aristar-wt-main-1234",
            createdAt: Date(),
            displayName: "Alias A",
            previewServices: []
        )

        let itemA = WorkingSetItem(worktree: worktree, project: project)
        var itemB = itemA
        itemB.displayName = "Alias B"

        XCTAssertEqual(itemA, itemB)
    }
}
