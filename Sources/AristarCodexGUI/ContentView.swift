import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        ZStack {
            BrandColor.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(model: model)
                    .padding(.bottom, 8)

                if let restoreError = model.restoreError {
                    BannerView(
                        text: restoreError,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: BrandColor.citrus
                    )
                    .padding(.horizontal)
                }
                if let hubError = model.hubError {
                    BannerView(
                        text: hubError,
                        systemImage: "exclamationmark.triangle.fill",
                        tint: BrandColor.citrus
                    )
                    .padding(.horizontal)
                }

                Group {
                    switch model.selectedTab {
                    case .hubs:
                        HubsPage(model: model)
                    case .workingSet:
                        WorkingSetPage(model: model)
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

// MARK: - Header

private struct HeaderBar: View {
    @ObservedObject var model: AppModel

    private func pickFolder(_ onPicked: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                onPicked(url)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(BrandColor.ion.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "atom")
                            .foregroundStyle(BrandColor.ion)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text("Aristar Codex")
                        .font(BrandFont.display(size: 18, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                }

                FolderPickerButton { url in
                    let ref = ProjectRef(url: url)
                    model.selectProject(ref)
                }
                .buttonStyle(.brandGhost)
                .help("Open a project folder")

                Spacer()

                TabSwitcher(selectedTab: $model.selectedTab)
            }

            HStack(spacing: 12) {
                if let project = model.selectedProject {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(BrandColor.ion)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(BrandFont.ui(size: 14, weight: .semibold))
                                .foregroundStyle(BrandColor.flour)
                            Text(project.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } else {
                    Text("No project selected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CodexStatusView(status: model.codexAuth.status) {
                    model.codexAuth.loginViaChatGPT()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .brandPanel(cornerRadius: BrandRadius.xl)
        .shadow(color: .clear, radius: 0)
    }
}

private struct TabSwitcher: View {
    @Binding var selectedTab: HubTab
    private let tabs: [HubTab] = [.hubs, .workingSet]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.self) { tab in
                let isActive = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.iconName)
                        Text(tab.title)
                            .font(BrandFont.ui(size: 14, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(isActive ? BrandColor.flour : BrandColor.flour.opacity(0.9))
                }
                .buttonStyle(.plain)
                .brandPill(active: isActive)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(BrandColor.orbit.opacity(0.4))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(BrandColor.ion.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct CodexStatusView: View {
    let status: CodexAuthManager.Status
    let onConnect: () -> Void

    var body: some View {
        switch status {
        case .loggedIn:
            Label("Codex: Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColor.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(BrandColor.mint.opacity(0.15)))
        case .loggedOut:
            Button(action: onConnect) {
                Label("Connect Codex", systemImage: "person.badge.key")
                    .font(BrandFont.ui(size: 13, weight: .semibold))
            }
            .buttonStyle(.brandPrimary)
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking Codex…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(BrandColor.citrus)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(BrandColor.citrus.opacity(0.15)))
        case .unknown:
            EmptyView()
        }
    }
}

private extension HubTab {
    var title: String {
        switch self {
        case .hubs: return "Hubs"
        case .workingSet: return "Working Set"
        }
    }

    var iconName: String {
        switch self {
        case .hubs: return "square.grid.2x2"
        case .workingSet: return "tray.full"
        }
    }
}

// MARK: - Hubs

private struct HubsPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ProjectHubColumn(model: model)
                .frame(width: 280)

            VStack(alignment: .leading, spacing: 12) {
                BranchListPanel(model: model)
                BranchPanesView(model: model)
            }
            .padding(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

private struct ProjectHubColumn: View {
    @ObservedObject var model: AppModel
    @State private var pendingRemoval: ProjectRef?

    var body: some View {
        let totalProjects = Set((model.favorites + model.recents).map { $0.id }).count

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle")
                    .foregroundStyle(BrandColor.ion)
                Text("Projects")
                    .font(BrandFont.display(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                Spacer()
                if totalProjects > 0 {
                    Text("\(totalProjects)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brandPill(active: true)
                        .foregroundStyle(BrandColor.flour)
                }
            }

            if !model.favorites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Favorites", systemImage: "star.fill")
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    ForEach(model.favorites) { project in
                        ProjectInboxRow(
                            project: project,
                            isSelected: model.selectedProject == project,
                            isFavorite: true,
                            onSelect: { model.selectProject(project) },
                            onToggleFavorite: { model.removeFavorite(project) },
                            onRemove: { pendingRemoval = project }
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Recents", systemImage: "clock")
                    .font(BrandFont.ui(size: 13, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                if model.recents.isEmpty {
                    Text("No recent projects yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recents) { project in
                        let isFav = model.favorites.contains(project)
                        ProjectInboxRow(
                            project: project,
                            isSelected: model.selectedProject == project,
                            isFavorite: isFav,
                            onSelect: { model.selectProject(project) },
                            onToggleFavorite: {
                                if isFav {
                                    model.removeFavorite(project)
                                } else {
                                    model.addFavorite(project)
                                }
                            },
                            onRemove: { pendingRemoval = project }
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .brandPanel()
        .shadow(color: .clear, radius: 0)
        .confirmationDialog(
            "Remove project?",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { value in if !value { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove and delete managed worktrees", role: .destructive) {
                if let target = pendingRemoval {
                    model.removeProjectCompletely(target)
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            Text("This removes the project from favorites/recents and deletes all Aristar-managed worktrees and branches for it.")
        }
    }
}

private struct ProjectInboxRow: View {
    let project: ProjectRef
    let isSelected: Bool
    let isFavorite: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isFavorite ? BrandColor.ion : BrandColor.orbit.opacity(0.6))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                        .lineLimit(1)
                    Text(project.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                HStack(spacing: 6) {
                    Button {
                        onToggleFavorite()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundStyle(isFavorite ? BrandColor.ion : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    if let onRemove {
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(BrandColor.berry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                    .fill(isSelected ? BrandColor.ion.opacity(0.2) : BrandColor.midnight.opacity(0.85))
            )
            .overlay(
                Rectangle()
                    .fill(BrandColor.ion.opacity(isSelected ? 0.9 : 0))
                    .frame(width: 3),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BranchListPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Branches", systemImage: "arrow.triangle.branch")
                    .font(BrandFont.display(size: 15, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                Spacer()
                if let project = model.selectedProject {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let _ = model.selectedProject {
                if model.branchesForSelected.isEmpty {
                    Text("No branches found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.branchesForSelected, id: \.self) { branch in
                                let hasPane = model.branchPanes.contains { $0.project == model.selectedProject && $0.branch == branch }
                                let isActive = model.selectedBranchName == branch || hasPane
                                Button {
                                    if let project = model.selectedProject {
                                        model.openBranchPane(for: project, branch: branch)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.branch")
                                        Text(branch)
                                            .font(BrandFont.ui(size: 13, weight: .semibold))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(isActive ? BrandColor.flour : BrandColor.flour.opacity(0.9))
                                }
                                .buttonStyle(.plain)
                                .brandPill(active: isActive)
                                .help(branch)
                            }
                        }
                    }
                }
            } else {
                Text("Select a project to view branches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .brandPanel()
        .shadow(color: .clear, radius: 0)
    }
}

private struct BranchPanesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.branchPanes.isEmpty {
            VStack(spacing: 12) {
                Text("Open a branch to manage its worktrees.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .brandPanel()
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.lg, style: .continuous)
                    .strokeBorder(BrandColor.ion.opacity(0.15), lineWidth: 1.5)
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(model.branchPanes) { pane in
                        BranchPaneCard(model: model, pane: pane)
                            .frame(width: 360)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct BranchPaneCard: View {
    @ObservedObject var model: AppModel
    let pane: BranchPane
    @State private var pendingDelete: ManagedWorktree?

    private func isRunning(_ worktree: ManagedWorktree) -> Bool {
        model.session(for: worktree, project: pane.project) != nil
    }

    private var selectedWorktree: ManagedWorktree? {
        guard let selectedID = pane.selectedWorktreeID else { return nil }
        return pane.worktrees.first(where: { $0.id == selectedID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundStyle(BrandColor.flour.opacity(0.8))
                    Text(pane.project.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BrandColor.flour.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(BrandColor.midnight.opacity(0.85))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(BrandColor.orbit.opacity(0.35), lineWidth: 1)
                )

                Spacer()

                Label(pane.branch, systemImage: "arrow.triangle.branch")
                    .font(BrandFont.display(size: 15, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(BrandColor.flour)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(BrandColor.midnight.opacity(0.78))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(BrandColor.ion.opacity(0.5), lineWidth: 1.2)
                    )
                    .help(pane.branch)
            }

            if let error = pane.error {
                BannerView(text: error, systemImage: "exclamationmark.triangle.fill", tint: BrandColor.citrus)
            }

            if pane.worktrees.isEmpty {
                Text("No managed worktrees for this branch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(pane.worktrees) { wt in
                        let running = isRunning(wt)
                        WorktreeRow(
                            worktree: wt,
                            isRunning: running,
                            isInWorkingSet: model.isInWorkingSet(worktree: wt),
                            onSelect: { model.selectWorktree(wt, in: pane) },
                            onLaunch: {
                                model.selectWorktree(wt, in: pane)
                                _ = model.launch(worktree: wt, project: pane.project)
                            },
                            onStop: {
                                model.selectWorktree(wt, in: pane)
                                model.stop(worktree: wt, project: pane.project)
                            },
                            onAddToWorkingSet: {
                                model.selectWorktree(wt, in: pane)
                                model.addToWorkingSet(worktree: wt, project: pane.project)
                            },
                            onRemoveFromWorkingSet: {
                                model.selectWorktree(wt, in: pane)
                                model.removeFromWorkingSet(worktree: wt, project: pane.project)
                            },
                            onDelete: { pendingDelete = wt }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }

            ActionPill(
                fill: BrandColor.ion.opacity(0.9),
                stroke: BrandColor.ion.opacity(0.9),
                foreground: BrandColor.ink,
                padding: EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
            ) {
                model.createWorktree(in: pane)
            } label: {
                Image(systemName: "plus")
                Text("Create Worktree")
            }
            .disabled(model.isManagedRoot(pane.project))
            .opacity(model.isManagedRoot(pane.project) ? 0.6 : 1)
            .help(model.isManagedRoot(pane.project) ? "Open the main repository to create worktrees." : "Create a managed worktree for this branch.")
        }
        .padding(14)
        .brandPanel()
        .shadow(color: BrandColor.ion.opacity(0.08), radius: 10, y: 4)
        .confirmationDialog(
            "Delete worktree?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { value in if !value { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = pendingDelete {
                    model.deleteWorktree(target, in: pane)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            if let target = pendingDelete {
                Text("This will remove \(target.displayName) and its agent branch.")
            }
        }
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
                        .font(BrandFont.display(size: 18, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Label(worktree.originalBranch, systemImage: "arrow.triangle.branch")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        .buttonStyle(.brandPrimary)
                    }

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete worktree", systemImage: "trash")
                    }
                    .buttonStyle(.brandDanger)
                }
            }

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
                    .buttonStyle(.brandPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .brandPanel()
        .shadow(color: .clear, radius: 0)
    }
}

// MARK: - Working set

private enum WorkingSetDetailTab: String, CaseIterable {
    case agent = "Agent"
    case preview = "Preview"
}

private struct WorkingSetPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            WorkingSetSidebar(model: model)
                .frame(width: 280)

            WorkingSetDetail(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .onAppear {
            if model.selectedWorkingSetID == nil {
                model.selectedWorkingSetID = model.workingSet.first?.id
            }
        }
        .onChange(of: model.workingSet) { newValue in
            if let selected = model.selectedWorkingSetID,
               !newValue.contains(where: { $0.id == selected }) {
                model.selectedWorkingSetID = newValue.first?.id
            }
        }
    }
}

private struct WorkingSetSidebar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Working Set", systemImage: "tray.full")
                    .font(BrandFont.display(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                Spacer()
                if !model.workingSet.isEmpty {
                    Text("\(model.workingSet.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .brandPill(active: true)
                }
            }

            if model.workingSet.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No items yet.")
                        .font(BrandFont.ui(size: 14, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text("Add worktrees from branch panes to build your working set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(model.workingSet) { item in
                            let isSelected = model.selectedWorkingSetID == item.id
                            WorkingSetSidebarRow(
                                item: item,
                                isSelected: isSelected,
                                isRunning: model.worktree(from: item).flatMap { wt in model.session(for: wt, project: item.project) } != nil,
                                onSelect: { model.selectWorkingSet(item: item) },
                                onRemove: { model.removeFromWorkingSet(item) }
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .brandPanel()
        .shadow(color: .clear, radius: 0)
    }
}

private struct WorkingSetSidebarRow: View {
    let item: WorkingSetItem
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRunning ? BrandColor.mint : BrandColor.orbit.opacity(0.6))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.project.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(BrandColor.midnight))
                            .foregroundStyle(BrandColor.flour.opacity(0.9))
                        Text(item.originalBranch)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .help("Remove from working set")
                .foregroundStyle(BrandColor.berry)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                    .fill(isSelected ? BrandColor.ion.opacity(0.2) : BrandColor.midnight.opacity(0.8))
            )
            .overlay(
                Rectangle()
                    .fill(BrandColor.ion.opacity(isSelected ? 0.85 : 0))
                    .frame(width: 3)
                , alignment: .leading
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WorkingSetDetail: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let item = model.selectedWorkingSetItem, let wt = model.worktree(from: item) {
            WorktreeDetailTabs(model: model, item: item, worktree: wt)
                .brandPanel()
                .shadow(color: .clear, radius: 0)
        } else if model.workingSet.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Add worktrees from branch panes to build your working set.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .brandPanel()
            .shadow(color: .clear, radius: 0)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Worktree not found. Remove it from the working set.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .brandPanel()
            .shadow(color: .clear, radius: 0)
        }
    }
}

private struct WorktreeDetailTabs: View {
    @ObservedObject var model: AppModel
    let item: WorkingSetItem
    @State private var worktree: ManagedWorktree
    @State private var tab: WorkingSetDetailTab = .agent
    @State private var previewServices: [PreviewServiceConfig]
    @State private var hasLoadedPreview = false

    init(model: AppModel, item: WorkingSetItem, worktree: ManagedWorktree) {
        self.model = model
        self.item = item
        _worktree = State(initialValue: worktree)
        let previews = model.previewConfigs(for: worktree, project: item.project)
        _previewServices = State(initialValue: previews)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorktreeHeader(item: item, worktree: worktree)

            WorktreeTabSwitcher(selectedTab: $tab)

            switch tab {
            case .agent:
                AgentDetailView(model: model, item: item, worktree: worktree)
            case .preview:
                PreviewDetailView(model: model, item: item, worktree: $worktree, services: $previewServices)
            }
        }
        .padding()
        .onAppear { reloadPreview() }
        .onChange(of: item.id) { _ in
            tab = .agent
            reloadPreview()
        }
        .onChange(of: worktree.id) { _ in
            tab = .agent
            reloadPreview()
        }
        .onChange(of: previewServices) { services in
            guard hasLoadedPreview else { return }
            worktree = model.savePreviewConfigs(services, for: worktree, project: item.project)
        }
    }

    private func reloadPreview() {
        model.previewError = nil
        previewServices = model.previewConfigs(for: worktree, project: item.project)
        hasLoadedPreview = true
    }
}

private struct WorktreeTabSwitcher: View {
    @Binding var selectedTab: WorkingSetDetailTab
    private let tabs: [(WorkingSetDetailTab, String, String)] = [
        (.agent, "bolt.fill", "Agent"),
        (.preview, "sparkles.rectangle.stack", "Preview")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tabs, id: \.0) { tab, icon, title in
                let isActive = selectedTab == tab
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                        Text(title)
                            .font(BrandFont.ui(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(isActive ? BrandColor.flour : BrandColor.flour.opacity(0.9))
                }
                .buttonStyle(.plain)
                .brandPill(active: isActive)
                .keyboardShortcut(tab == .agent ? "3" : "4", modifiers: .command)
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(BrandColor.orbit.opacity(0.35))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(BrandColor.ion.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct WorktreeHeader: View {
    let item: WorkingSetItem
    let worktree: ManagedWorktree

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(worktree.displayName)
                .font(BrandFont.display(size: 18, weight: .semibold))
                .foregroundStyle(BrandColor.flour)
            HStack(spacing: 8) {
                Label(item.project.name, systemImage: "folder")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(BrandColor.midnight))
                    .foregroundStyle(BrandColor.flour)
                Label(item.originalBranch, systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
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
                .help("Copy path")
            }
        }
    }
}

private struct AgentDetailView: View {
    @ObservedObject var model: AppModel
    let item: WorkingSetItem
    let worktree: ManagedWorktree

    private var running: Bool {
        model.session(for: worktree, project: item.project) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if running {
                    Button(role: .destructive) {
                        model.stop(worktree: worktree, project: item.project)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.brandDanger)

                    Button {
                        _ = model.resume(worktree: worktree, project: item.project)
                    } label: {
                        Label("Resume", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.brandGhost)
                } else {
                    Button {
                        _ = model.launch(worktree: worktree, project: item.project)
                    } label: {
                        Label("Start agent", systemImage: "play.fill")
                    }
                    .buttonStyle(.brandPrimary)

                    Button {
                        _ = model.resume(worktree: worktree, project: item.project)
                    } label: {
                        Label("Resume", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.brandGhost)
                }

                Spacer()
            }

            Divider()

            if let session = model.session(for: worktree, project: item.project) {
                CodexSessionView(session: session) {
                    model.stop(worktree: worktree, project: item.project)
                }
            } else {
                VStack(spacing: 8) {
                    Text("No agent running.")
                        .foregroundStyle(.secondary)
                    Button {
                        _ = model.launch(worktree: worktree, project: item.project)
                    } label: {
                        Label("Start agent", systemImage: "play.fill")
                    }
                    .buttonStyle(.brandPrimary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PreviewDetailView: View {
    @ObservedObject var model: AppModel
    let item: WorkingSetItem
    @Binding var worktree: ManagedWorktree
    @Binding var services: [PreviewServiceConfig]
    @State private var expanded: Set<UUID> = []

    private var runningSessions: [PreviewServiceSession] {
        let sessions = model.previewSessions[worktree.id] ?? [:]
        return Array(sessions.values).sorted { $0.name < $1.name }
    }

    private func resolvedRoot(for service: PreviewServiceConfig) -> String {
        let trimmed = service.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return worktree.path.path }
        if trimmed.hasPrefix("/") { return trimmed }
        let relative = trimmed.hasPrefix("./") ? String(trimmed.dropFirst(2)) : trimmed
        return worktree.path.appendingPathComponent(relative).path
    }

    private func isValidRoot(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func canStartPreview() -> Bool {
        let enabled = services.filter { $0.enabled }
        guard !enabled.isEmpty else { return false }
        return enabled.allSatisfy { service in
            !service.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            isValidRoot(resolvedRoot(for: service))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Label("Starting Script", systemImage: "sparkles.rectangle.stack")
                        .font(BrandFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Spacer()
                    Button {
                        worktree = model.savePreviewConfigs(services, for: worktree, project: item.project)
                        if runningSessions.isEmpty {
                            model.startPreview(for: worktree, services: services)
                        } else {
                            model.stopPreview(for: worktree)
                        }
                    } label: {
                        Label(runningSessions.isEmpty ? "Start preview" : "Stop all", systemImage: runningSessions.isEmpty ? "play.fill" : "stop.fill")
                    }
                    .buttonStyle(runningSessions.isEmpty ? .brandPrimary : .brandDanger)

                    Button {
                        var service = PreviewServiceConfig()
                        service.name = "Service \(services.count + 1)"
                        service.rootPath = worktree.path.path
                        services.append(service)
                        expanded.insert(service.id)
                    } label: {
                        Label("Add service", systemImage: "plus")
                    }
                    .buttonStyle(.brandGhost)
                }

                if services.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Add services to define your preview.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .brandCard()
                } else {
                    let columns = [GridItem(.adaptive(minimum: 440), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(services.indices), id: \.self) { index in
                            let binding = $services[index]
                            let service = binding.wrappedValue
                            let isRunning = model.isPreviewRunning(serviceID: service.id, worktree: worktree)
                            PreviewServiceCard(
                                service: binding,
                                defaultRoot: worktree.path.path,
                                isRunning: isRunning,
                                isExpanded: Binding(
                                    get: { expanded.contains(service.id) },
                                    set: { value in
                                        if value { expanded.insert(service.id) } else { expanded.remove(service.id) }
                                    }
                                ),
                                onStart: {
                                    worktree = model.savePreviewConfigs(services, for: worktree, project: item.project)
                                    _ = model.startPreviewService(service, worktree: worktree)
                                },
                                onStop: {
                                    model.stopPreviewService(service.id, worktree: worktree)
                                },
                                onRemove: {
                                    let serviceID = service.id
                                    if services.indices.contains(index) {
                                        services.remove(at: index)
                                    } else {
                                        services.removeAll { $0.id == serviceID }
                                    }
                                    expanded.remove(serviceID)
                                }
                            )
                        }
                    }
                }

                if let error = model.previewError {
                    BannerView(text: error, systemImage: "exclamationmark.triangle.fill", tint: BrandColor.citrus)
                }

                PreviewTerminalGrid(model: model, worktree: worktree, runningSessions: runningSessions)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
        }
        .onAppear {
            expanded = []
        }
    }
}

private struct PreviewTerminalGrid: View {
    @ObservedObject var model: AppModel
    let worktree: ManagedWorktree
    let runningSessions: [PreviewServiceSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            if runningSessions.isEmpty {
                Text("No preview services running.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                let columns = runningSessions.count > 1 ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())]
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(runningSessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(session.isRunning ? BrandColor.mint : BrandColor.orbit.opacity(0.6))
                                    .frame(width: 10, height: 10)
                                Text(session.name)
                                    .font(BrandFont.ui(size: 13, weight: .semibold))
                                    .foregroundStyle(BrandColor.flour)
                                Spacer()
                                Button(role: .destructive) {
                                    model.stopPreviewService(session.serviceID, worktree: worktree)
                                } label: {
                                    Image(systemName: "stop.circle")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(BrandColor.berry)
                            }

                            PreviewTerminalContainer(session: session)
                                .frame(minHeight: 220)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                                        .fill(BrandColor.midnight.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                                        .stroke(BrandColor.orbit.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
}

private struct PreviewServiceCard: View {
    @Binding var service: PreviewServiceConfig
    let defaultRoot: String
    let isRunning: Bool
    @Binding var isExpanded: Bool
    @State private var showEnv: Bool = false
    @State private var confirmDelete: Bool = false
    let onStart: () -> Void
    let onStop: () -> Void
    let onRemove: () -> Void

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: defaultRoot)
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                service.rootPath = url.path
            }
        }
    }

    private var hasCommand: Bool {
        !service.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedRoot: String {
        let trimmed = service.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return defaultRoot }
        if trimmed.hasPrefix("/") { return trimmed }
        let relative = trimmed.hasPrefix("./") ? String(trimmed.dropFirst(2)) : trimmed
        return URL(fileURLWithPath: defaultRoot).appendingPathComponent(relative).path
    }

    private var hasValidRoot: Bool {
        let path = resolvedRoot
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private var displayPath: String {
        let trimmed = service.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "./" }
        if trimmed.hasPrefix("/") {
            if trimmed.hasPrefix(defaultRoot) {
                let rel = trimmed.replacingOccurrences(of: defaultRoot, with: "")
                let trimmedRel = rel.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return "./\(trimmedRel.isEmpty ? "." : trimmedRel)"
            }
            return trimmed
        }
        if trimmed.hasPrefix("./") { return trimmed }
        return "./\(trimmed)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name.isEmpty ? "Service" : service.name)
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text(displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Toggle("Include", isOn: $service.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .help("Include in Start preview")
                    .frame(width: 46)
                HStack(spacing: 8) {
                    if isRunning {
                        Button(role: .destructive) {
                            onStop()
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.brandDanger)
                        .help("Stop this service")
                    } else {
                        Button {
                            onStart()
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.brandPrimary)
                        .disabled(!service.enabled || !hasCommand || !hasValidRoot)
                        .help("Start this service")
                    }
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.brandGhost)
                    .help(isExpanded ? "Hide service config" : "Edit service config")
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "command")
                    .foregroundStyle(.secondary)
                Text(service.command.isEmpty ? "Add a command" : service.command)
                    .font(.caption)
                    .foregroundStyle(service.command.isEmpty ? .secondary : BrandColor.flour)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Service name", text: $service.name)
                            .textFieldStyle(BrandFieldStyle())
                    }

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Root")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Relative to worktree (e.g. frontend)", text: $service.rootPath, prompt: Text("Relative to worktree (e.g. ./frontend)"))
                                .textFieldStyle(BrandFieldStyle())
                        }
                        Button {
                            pickFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.borderless)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Command")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Command to run (e.g., cd backend && pnpm install && pnpm run dev)", text: $service.command)
                            .textFieldStyle(BrandFieldStyle())
                    }

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showEnv.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf")
                            Text(showEnv ? "Hide env" : "Edit env")
                        }
                    }
                    .buttonStyle(.brandGhost)

                    if showEnv {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Env (optional)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $service.envText)
                                .frame(minHeight: 80)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                                        .fill(BrandColor.midnight.opacity(0.8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                                        .stroke(BrandColor.orbit.opacity(0.25), lineWidth: 1)
                                )
                        }
                        .transition(.opacity.combined(with: .slide))
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete service", systemImage: "trash")
                    }
                    .buttonStyle(.brandDanger)
                    .help("Delete this service")
                }
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .fill(BrandColor.midnight.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
        )
        .confirmationDialog(
            "Delete this service?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { onRemove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the service from the Starting Script.")
        }
    }
}

// MARK: - Shared views

private struct WorktreeRow: View {
    let worktree: ManagedWorktree
    let isRunning: Bool
    let isInWorkingSet: Bool
    let onSelect: () -> Void
    let onLaunch: () -> Void
    let onStop: () -> Void
    let onAddToWorkingSet: () -> Void
    let onRemoveFromWorkingSet: (() -> Void)?
    let onDelete: () -> Void

    private var statusColor: Color { isRunning ? .green : .gray.opacity(0.6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isRunning ? BrandColor.mint : BrandColor.orbit.opacity(0.6))
                    .frame(width: 10, height: 10)
                ZStack {
                    Circle()
                        .fill(BrandColor.midnight)
                        .frame(width: 28, height: 28)
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(isInWorkingSet ? BrandColor.ion : BrandColor.flour.opacity(0.85))
                        .font(.system(size: 13, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(worktree.displayName)
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                        .lineLimit(1)
                    Text(worktree.path.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if isInWorkingSet {
                    Text("In working set")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous)
                                .fill(BrandColor.ion.opacity(0.1))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(BrandColor.ion.opacity(0.6), lineWidth: 1)
                        )
                        .foregroundStyle(BrandColor.ion)
                }
            }

            HStack(spacing: 10) {
                ActionPill(
                    fill: BrandColor.midnight.opacity(0.85),
                    stroke: BrandColor.orbit.opacity(0.35),
                    padding: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
                ) {
                    copyPath(worktree.path.path)
                } label: {
                    Image(systemName: "doc.on.doc")
                    Text("Copy path")
                }

                Spacer()
                if isRunning {
                    Button(role: .destructive) {
                        onStop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.brandDanger)
                } else if !isInWorkingSet {
                    Button {
                        onAddToWorkingSet()
                    } label: {
                        Label("Add", systemImage: "plus.circle")
                    }
                    .buttonStyle(.brandPrimary)
                }

                if isInWorkingSet {
                    Button(role: .destructive) {
                        (onRemoveFromWorkingSet ?? onDelete)()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .help("Remove from working set")
                    .foregroundStyle(BrandColor.citrus)
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(BrandColor.berry)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(BrandColor.midnight.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(BrandColor.orbit.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .clear, radius: 0)
        .onTapGesture { onSelect() }
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
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct ActionPill<Label: View>: View {
    let fill: Color
    let stroke: Color
    var foreground: Color = BrandColor.flour
    var padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    let action: () -> Void
    let label: () -> Label

    init(fill: Color, stroke: Color, foreground: Color = BrandColor.flour, padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12), action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.fill = fill
        self.stroke = stroke
        self.foreground = foreground
        self.padding = padding
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
                    .font(BrandFont.ui(size: 13, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(padding)
            .foregroundStyle(foreground)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 1.1)
            )
        }
        .buttonStyle(.plain)
    }
}

private func copyPath(_ path: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(path, forType: .string)
}

private struct BrandFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .fill(BrandColor.midnight.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .stroke(BrandColor.orbit.opacity(0.35), lineWidth: 1)
            )
            .foregroundStyle(BrandColor.flour)
    }
}
