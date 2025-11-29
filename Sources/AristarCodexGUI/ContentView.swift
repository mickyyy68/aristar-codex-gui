import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(model: model)

            if let restoreError = model.restoreError {
                BannerView(
                    text: restoreError,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
                .padding(.horizontal)
            }
            if let hubError = model.hubError {
                BannerView(
                    text: hubError,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
                .padding(.horizontal)
            }

            Divider()

            Group {
                switch model.selectedTab {
                case .hubs:
                    HubsPage(model: model)
                case .workingSet:
                    WorkingSetPage(model: model)
                }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("Aristar Codex", systemImage: "square.grid.2x2")
                    .font(.headline.weight(.semibold))

                FolderPickerButton { url in
                    let ref = ProjectRef(url: url)
                    model.selectProject(ref)
                }
                .help("Open a project folder")

                Button {
                    pickFolder { url in
                        let ref = ProjectRef(url: url)
                        model.addFavorite(ref)
                        model.selectProject(ref)
                    }
                } label: {
                    Label("Add Favorite", systemImage: "star")
                }
                .help("Pick a folder and pin it to favorites")

                Spacer()

                Picker("", selection: $model.selectedTab) {
                    Text("Hubs").tag(HubTab.hubs)
                    Text("Working Set").tag(HubTab.workingSet)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }

            HStack(spacing: 12) {
                if let project = model.selectedProject {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                        Text(project.name)
                            .font(.subheadline.weight(.semibold))
                        Text(project.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text("No project selected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                switch model.codexAuth.status {
                case .loggedIn:
                    Label("Codex: Connected", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                case .loggedOut:
                    Button {
                        model.codexAuth.loginViaChatGPT()
                    } label: {
                        Label("Connect Codex", systemImage: "person.badge.key")
                    }
                    .buttonStyle(.bordered)
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
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .unknown:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects")
                .font(.headline)

            if !model.favorites.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Favorites", systemImage: "star.fill")
                        .font(.subheadline)
                    ForEach(model.favorites) { project in
                        ProjectRow(
                            title: project.name,
                            subtitle: project.path,
                            isSelected: model.selectedProject == project,
                            onSelect: { model.selectProject(project) },
                            accessory: {
                                Button {
                                    model.removeFavorite(project)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Recents", systemImage: "clock")
                    .font(.subheadline)
                if model.recents.isEmpty {
                    Text("No recent projects yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recents) { project in
                        ProjectRow(
                            title: project.name,
                            subtitle: project.path,
                            isSelected: model.selectedProject == project,
                            onSelect: { model.selectProject(project) },
                            accessory: {
                                Group {
                                    if !model.favorites.contains(project) {
                                        Button {
                                            model.addFavorite(project)
                                        } label: {
                                            Image(systemName: "star")
                                        }
                                        .buttonStyle(.borderless)
                                    } else {
                                        EmptyView()
                                    }
                                }
                            }
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct ProjectRow<Accessory: View>: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void
    let accessory: () -> Accessory

    init(title: String, subtitle: String, isSelected: Bool, onSelect: @escaping () -> Void, accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.accessory = accessory
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                accessory()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
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
                    .font(.headline)
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
                                let isActive = model.selectedBranchName == branch || model.branchPanes.contains(where: { $0.branch == branch && $0.project == model.selectedProject })
                                Button {
                                    if let project = model.selectedProject {
                                        model.openBranchPane(for: project, branch: branch)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.branch")
                                        Text(branch)
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(isActive ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(isActive ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.borderless)
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

private struct BranchPanesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.branchPanes.isEmpty {
            VStack(spacing: 12) {
                Text("Open a branch to manage its worktrees.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pane.project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(pane.branch)
                        .font(.headline.weight(.semibold))
                }
                Spacer()
                Button {
                    model.createWorktree(in: pane)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .disabled(model.isManagedRoot(pane.project))
                .help(model.isManagedRoot(pane.project) ? "Open the main repository to create worktrees." : "Create a managed worktree for this branch.")

                Button {
                    model.refreshPane(pane)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            if let error = pane.error {
                BannerView(text: error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
            }

            if pane.worktrees.isEmpty {
                Text("No managed worktrees for this branch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
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
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
                        .font(.title3.weight(.semibold))
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

// MARK: - Working set

private struct WorkingSetPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            WorkingSetSidebar(model: model)
                .frame(width: 260)
                .background(Color(.windowBackgroundColor))

            Divider()

            WorkingSetDetail(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                    .font(.headline)
                Spacer()
                if !model.workingSet.isEmpty {
                    Text("\(model.workingSet.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }
            }

            if model.workingSet.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .foregroundStyle(.secondary)
                    Text("No items yet.")
                        .font(.subheadline.weight(.semibold))
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
                    .fill(isRunning ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.project.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
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
                .buttonStyle(.borderless)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                Rectangle()
                    .fill(Color.accentColor.opacity(isSelected ? 0.8 : 0))
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
            WorkingSetDetailBody(model: model, item: item, worktree: wt)
        } else if model.workingSet.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Add worktrees from branch panes to build your working set.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Worktree not found. Remove it from the working set.")
                    .foregroundStyle(.secondary)
                if let item = model.selectedWorkingSetItem {
                    Button(role: .destructive) {
                        model.removeFromWorkingSet(item)
                    } label: {
                        Label("Remove from working set", systemImage: "minus.circle")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WorkingSetDetailBody: View {
    @ObservedObject var model: AppModel
    let item: WorkingSetItem
    let worktree: ManagedWorktree

    private var running: Bool {
        model.session(for: worktree, project: item.project) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(worktree.displayName)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 8) {
                        Label(item.project.name, systemImage: "folder")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                        Label(item.originalBranch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                    }
                    Text(worktree.path.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    if running {
                        Button(role: .destructive) {
                            model.stop(worktree: worktree, project: item.project)
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            _ = model.launch(worktree: worktree, project: item.project)
                        } label: {
                            Label("Launch", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button {
                        model.removeFromWorkingSet(item)
                    } label: {
                        Label("Remove from working set", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        model.deleteWorktree(worktree, project: item.project)
                    } label: {
                        Label("Delete worktree", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
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
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundStyle(isInWorkingSet ? .blue : .primary)
                Text(worktree.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                if isInWorkingSet {
                    Text("In working set")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue.opacity(0.15)))
                }
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
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
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                Spacer()
                if isRunning {
                    Button(role: .destructive) {
                        onStop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    if isInWorkingSet {
                        Button(role: .destructive) {
                            (onRemoveFromWorkingSet ?? onDelete)()
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            onAddToWorkingSet()
                        } label: {
                            Label("Add", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                if isInWorkingSet {
                    Button(role: .destructive) {
                        (onRemoveFromWorkingSet ?? onDelete)()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
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

private func copyPath(_ path: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(path, forType: .string)
}
