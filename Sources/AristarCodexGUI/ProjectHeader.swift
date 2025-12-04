import SwiftUI
import AppKit

/// Header bar showing current project with switcher dropdown
struct ProjectHeader: View {
    @ObservedObject var model: AppModel
    @State private var showSwitcher = false
    @State private var showBranchPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Project switcher button
            Button {
                showSwitcher.toggle()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(BrandColor.ion.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Image(systemName: "folder.fill")
                            .foregroundStyle(BrandColor.ion)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    if let project = model.currentProject {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(BrandFont.display(size: 16, weight: .semibold))
                                .foregroundStyle(BrandColor.flour)
                                .lineLimit(1)
                            
                            Text(project.path)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                        .fill(BrandColor.midnight.opacity(0.6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                        .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSwitcher, arrowEdge: .bottom) {
                ProjectSwitcher(model: model, isPresented: $showSwitcher)
            }
            
            Spacer()
            
            // Branch picker for new worktree
            if model.currentProject != nil {
                Button {
                    showBranchPicker.toggle()
                } label: {
                    Label("New Worktree", systemImage: "plus")
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                }
                .buttonStyle(.brandPrimary)
                .popover(isPresented: $showBranchPicker, arrowEdge: .bottom) {
                    BranchPickerPopover(model: model, isPresented: $showBranchPicker)
                }
                .disabled(model.isManagedRoot)
                .help(model.isManagedRoot ? "Open the main repository to create worktrees" : "Create a new worktree")
            }
            
            // Codex status
            CodexStatusBadge(status: model.codexAuth.status) {
                model.codexAuth.loginViaChatGPT()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(BrandColor.midnight.opacity(0.5))
    }
}

/// Dropdown for switching between projects
struct ProjectSwitcher: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.favorites.isEmpty {
                Text("Favorites")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                
                ForEach(model.favorites) { project in
                    ProjectSwitcherRow(
                        project: project,
                        isFavorite: true,
                        isSelected: model.currentProject == project,
                        onSelect: {
                            model.openProject(project)
                            isPresented = false
                        },
                        onToggleFavorite: {
                            model.removeFavorite(project)
                        }
                    )
                }
            }
            
            if !model.recents.isEmpty {
                if !model.favorites.isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                }
                
                Text("Recents")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, model.favorites.isEmpty ? 8 : 0)
                
                ForEach(model.recents.prefix(5)) { project in
                    ProjectSwitcherRow(
                        project: project,
                        isFavorite: false,
                        isSelected: model.currentProject == project,
                        onSelect: {
                            model.openProject(project)
                            isPresented = false
                        },
                        onToggleFavorite: {
                            model.addFavorite(project)
                        }
                    )
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            Button {
                openFolderPicker()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("Open folder...")
                }
                .font(BrandFont.ui(size: 13, weight: .medium))
                .foregroundStyle(BrandColor.ion)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .frame(minWidth: 280)
        .background(BrandColor.midnight)
    }
    
    private func openFolderPicker() {
        isPresented = false
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                let ref = ProjectRef(url: url)
                model.openProject(ref)
            }
        }
    }
}

private struct ProjectSwitcherRow: View {
    let project: ProjectRef
    let isFavorite: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                if isSelected {
                    Circle()
                        .fill(BrandColor.ion)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
                
                Image(systemName: "folder")
                    .foregroundStyle(BrandColor.flour.opacity(0.7))
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 1) {
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
                
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? BrandColor.ion : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || isFavorite ? 1 : 0.3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .fill(isHovering ? BrandColor.orbit.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Popover for selecting a branch when creating a new worktree
private struct BranchPickerPopover: View {
    @ObservedObject var model: AppModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select branch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            if model.branchesForCurrentProject.isEmpty {
                Text("No branches found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.branchesForCurrentProject, id: \.self) { branch in
                            Button {
                                model.createWorktree(fromBranch: branch)
                                isPresented = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundStyle(.secondary)
                                    Text(branch)
                                        .font(BrandFont.ui(size: 13, weight: .medium))
                                        .foregroundStyle(BrandColor.flour)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                                        .fill(Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 240)
        .background(BrandColor.midnight)
    }
}

/// Compact Codex status badge
private struct CodexStatusBadge: View {
    let status: CodexAuthManager.Status
    let onConnect: () -> Void
    
    var body: some View {
        switch status {
        case .loggedIn:
            Label("Codex Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColor.mint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(BrandColor.mint.opacity(0.15)))
        case .loggedOut:
            Button(action: onConnect) {
                Label("Connect", systemImage: "person.badge.key")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.brandGhost)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Checking…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(BrandColor.citrus)
                .lineLimit(1)
        case .unknown:
            EmptyView()
        }
    }
}
