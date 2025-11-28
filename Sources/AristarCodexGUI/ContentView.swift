import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack {
            HStack {
                FolderPickerButton { url in
                    model.openProject(at: url)
                }

                Spacer()

                switch model.codexAuth.status {
                case .loggedIn:
                    Text("Codex: Connected").foregroundColor(.green)
                case .loggedOut:
                    Button("Connect Codex") {
                        model.codexAuth.loginViaChatGPT()
                    }
                case .checking:
                    ProgressView().controlSize(.small)
                case .error(let msg):
                    HStack(spacing: 8) {
                        Text("Codex error").foregroundColor(.red)
                        Text(msg).font(.caption)
                    }
                case .unknown:
                    EmptyView()
                }
            }
            .padding([.top, .horizontal])

            Divider()

            if let manager = model.sessionManager {
                SessionManagerView(manager: manager, branches: model.branches)
            } else {
                Spacer()
                Text("Open a project folder to begin.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

private struct SessionManagerView: View {
    @ObservedObject var manager: CodexSessionManager
    let branches: [String]

    var body: some View {
        NavigationSplitView {
            VStack {
                List(selection: Binding(
                    get: { manager.selectedSessionID },
                    set: { manager.selectedSessionID = $0 }
                )) {
                    ForEach(manager.sessions) { session in
                        SessionRow(session: session)
                            .tag(session.id)
                            .contextMenu {
                                contextMenu(for: session)
                            }
                    }
                    .onDelete { offsets in
                        offsets
                            .map { manager.sessions[$0] }
                            .forEach { session in
                                manager.closeSession(session)
                            }
                    }
                }
                .toolbar {
                    Button {
                        manager.addPlainSession()
                    } label: {
                        Image(systemName: "plus")
                    }
                    Button {
                        if let session = manager.selectedSession {
                            if session.agentBranch != nil {
                                manager.deleteBranch(for: session)
                            } else {
                                manager.closeSession(session)
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete selected agent/branch")
                    .disabled(manager.selectedSession == nil)
                }

                if manager.gitInfo.isGitRepo, !branches.isEmpty {
                    BranchCreationView(
                        branches: branches,
                        onCreate: { branch in
                            manager.addWorktreeSession(branch: branch)
                        },
                        errorMessage: manager.lastWorktreeError
                    )
                    .padding()
                }
            }
        } detail: {
            if let session = manager.selectedSession {
                CodexSessionView(session: session) {
                    manager.closeSession(session)
                }
            } else {
                Text("Select or create an agent.")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for session: CodexSession) -> some View {
        if session.agentBranch != nil {
            Button(role: .destructive) {
                manager.deleteBranch(for: session)
            } label: {
                Label("Delete Branch", systemImage: "trash")
            }
        } else {
            Button(role: .destructive) {
                manager.closeSession(session)
            } label: {
                Label("Delete Agent", systemImage: "trash")
            }
        }
    }
}

private struct SessionRow: View {
    let session: CodexSession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let branch = session.originalBranch {
                Text(branch)
                    .font(.headline)
                Text(session.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(session.title)
            }
        }
    }
}
