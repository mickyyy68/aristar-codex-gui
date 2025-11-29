import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        VStack {
            HStack {
                FolderPickerButton { url in
                    model.openProject(at: url)
                }

                if model.sessionManager == nil, let last = model.recentProjectURL {
                    Button {
                        model.restoreLastProjectIfAvailable()
                    } label: {
                        Label("Reopen Last Project", systemImage: "clock.arrow.circlepath")
                            .help(last.path)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                switch model.codexAuth.status {
                case .loggedIn:
                    Label("Codex: Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .loggedOut:
                    Button {
                        model.codexAuth.loginViaChatGPT()
                    } label: {
                        Label("Connect Codex", systemImage: "person.badge.key")
                    }
                case .checking:
                    ProgressView().controlSize(.small)
                case .error(let msg):
                    HStack(spacing: 8) {
                        Label("Codex error", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(msg).font(.caption)
                    }
                case .unknown:
                    EmptyView()
                }
            }
            .padding([.top, .horizontal])

            if let manager = model.sessionManager {
                BaseBranchToolbar(
                    branches: model.branches,
                    selected: model.baseBranch,
                    isManagedRoot: manager.isManagedRoot,
                    onSelect: { branch in
                        model.selectBaseBranch(branch)
                    }
                )
                .padding(.horizontal)
            }

            if let restoreError = model.restoreError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(restoreError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()

            if let manager = model.sessionManager {
                ProjectWorkflowView(model: model, manager: manager)
            } else {
                Spacer()
                Text("Open a project folder to begin.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .task {
            model.restoreLastProjectIfAvailable()
        }
    }
}

private struct ProjectWorkflowView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var manager: CodexSessionManager

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    WorktreePanel(
                        worktrees: model.worktrees,
                        selectedID: model.selectedWorktreeID,
                        baseBranch: model.baseBranch,
                        isManagedRoot: manager.isManagedRoot,
                        isRunning: { worktree in manager.session(for: worktree) != nil },
                        onSelect: { worktree in model.selectWorktree(worktree) },
                        onCreate: { model.createWorktreeForBaseBranch() },
                        onDelete: { model.deleteSelectedWorktree() },
                        onReload: { model.reloadWorktrees() },
                        onLaunch: { worktree in model.selectWorktree(worktree); _ = model.launchAgentForSelectedWorktree() },
                        onStop: { worktree in model.selectWorktree(worktree); model.stopAgentForSelectedWorktree() }
                    )

                    if let worktreeError = model.worktreeError {
                        BannerView(
                            text: worktreeError,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        } detail: {
            if let worktree = model.selectedWorktree {
                WorktreeDetailView(
                    worktree: worktree,
                    session: model.sessionForSelectedWorktree(),
                    onLaunch: { _ = model.launchAgentForSelectedWorktree() },
                    onStop: { model.stopAgentForSelectedWorktree() },
                    onDelete: { model.delete(worktree: worktree) }
                )
            } else {
                Text("Select a worktree to manage agents.")
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct WorktreePanel: View {
    let worktrees: [ManagedWorktree]
    let selectedID: String?
    let baseBranch: String?
    let isManagedRoot: Bool
    let isRunning: (ManagedWorktree) -> Bool
    let onSelect: (ManagedWorktree) -> Void
    let onCreate: () -> Void
    let onDelete: () -> Void
    let onReload: () -> Void
    let onLaunch: (ManagedWorktree) -> Void
    let onStop: (ManagedWorktree) -> Void

    private var canCreate: Bool { baseBranch != nil && !isManagedRoot }
    private var canDelete: Bool { selectedID != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label("Worktrees", systemImage: "shippingbox")
                    .font(.headline)
                Spacer()
                Button {
                    onReload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("Reload worktrees for the selected base branch.")

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!canDelete)
                .help("Delete the selected managed worktree and its agent branch.")

                Button {
                    onCreate()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreate)
                .help(isManagedRoot ? "Open the main repository to create worktrees." : "Create a managed worktree from the selected base branch.")
            }

            if isManagedRoot {
                BannerView(
                    text: "This folder is already a managed worktree. Nested worktrees are blocked (depth limit 1).",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }

            if worktrees.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No worktrees for this branch yet.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            onCreate()
                        } label: {
                            Label("Create worktree", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canCreate)
                        .help(isManagedRoot ? "Open the main repository to create worktrees." : "Create from the selected base branch.")

                        if isManagedRoot {
                            Text("Creation blocked in managed worktree.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(worktrees) { worktree in
                        let running = isRunning(worktree)
                        WorktreeCard(
                            worktree: worktree,
                            isSelected: selectedID == worktree.id,
                            isRunning: running,
                            onSelect: { onSelect(worktree) },
                            onLaunch: { onSelect(worktree); onLaunch(worktree) },
                            onStop: { onSelect(worktree); onStop(worktree) }
                        )
                        .contextMenu {
                            Button {
                                onSelect(worktree)
                                onLaunch(worktree)
                            } label: {
                                Label("Launch agent", systemImage: "play.fill")
                            }
                            Button {
                                onSelect(worktree)
                                onStop(worktree)
                            } label: {
                                Label("Stop agent", systemImage: "stop.fill")
                            }
                            Divider()
                            Button(role: .destructive) {
                                onSelect(worktree)
                                onDelete()
                            } label: {
                                Label("Delete worktree", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct WorktreeCard: View {
    let worktree: ManagedWorktree
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onLaunch: () -> Void
    let onStop: () -> Void

    private var statusColor: Color { isRunning ? .green : .gray.opacity(0.6) }
    private var statusLabel: String { isRunning ? "Running" : "Stopped" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(statusLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isRunning ? .primary : .secondary)
                }
                Spacer()
                if isRunning {
                    Button(role: .destructive) {
                        onStop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        onLaunch()
                    } label: {
                        Label("Launch", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(worktree.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Label(worktree.originalBranch, systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                    Label(worktree.agentBranch, systemImage: "number")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.12)))
                }

                HStack(spacing: 8) {
                    Text(worktree.path.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        copyPath(worktree.path.path)
                    } label: {
                        Label("Copy path", systemImage: "doc.on.doc")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Copy worktree path to clipboard.")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { onSelect() }
    }
}

private struct WorktreeDetailView: View {
    let worktree: ManagedWorktree
    let session: CodexSession?
    let onLaunch: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(worktree.displayName)
                        .font(.title2.weight(.semibold))
                    Label(worktree.originalBranch, systemImage: "arrow.triangle.branch")
                        .font(.subheadline)
                    Label(worktree.agentBranch, systemImage: "number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let created = worktree.createdAt {
                        Text("Created \(dateFormatter.string(from: created))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        Text(worktree.path.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                        Button {
                            copyPath(worktree.path.path)
                        } label: {
                            Label("Copy path", systemImage: "doc.on.doc")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if session != nil {
                        Button(role: .destructive) {
                            onStop()
                        } label: {
                            Label("Stop agent", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            onLaunch()
                        } label: {
                            Label("Launch agent", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete worktree", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)

            Divider()

            if let session {
                CodexSessionView(session: session) {
                    onStop()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No agent running in this worktree.")
                        .foregroundStyle(.secondary)
                    Button {
                        onLaunch()
                    } label: {
                        Label("Start agent", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct BannerView: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.1))
        )
    }
}

private struct BaseBranchToolbar: View {
    let branches: [String]
    let selected: String?
    let isManagedRoot: Bool
    let onSelect: (String) -> Void

    private var displayedBranch: String {
        selected ?? branches.first ?? "No branch"
    }

    var body: some View {
        HStack(spacing: 8) {
            if isManagedRoot {
                Text("Managed")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
            }

            Menu {
                ForEach(branches, id: \.self) { branch in
                    Button(branch) {
                        onSelect(branch)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(displayedBranch)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .disabled(branches.isEmpty)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
    }
}

private func copyPath(_ path: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(path, forType: .string)
}
