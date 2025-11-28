import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var projectRoot: URL?
    @Published var sessionManager: CodexSessionManager?
    @Published var branches: [String] = []

    let codexAuth: CodexAuthManager

    init() {
        self.codexAuth = CodexAuthManager()
        self.codexAuth.checkStatus()
    }

    func openProject(at url: URL) {
        projectRoot = url
        let manager = CodexSessionManager(projectRoot: url, codexPath: codexAuth.codexPath)
        sessionManager = manager

        if manager.gitInfo.isGitRepo {
            switch GitService.listBranches(in: manager.gitInfo.repoRoot) {
            case .success(let list):
                branches = list
            case .failure:
                branches = []
            }
        } else {
            branches = []
        }
    }
}
