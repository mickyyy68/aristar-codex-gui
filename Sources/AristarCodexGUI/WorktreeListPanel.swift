import SwiftUI

/// Left panel showing all worktrees for the current project
struct WorktreeListPanel: View {
    @ObservedObject var model: AppModel
    @State private var pendingDelete: ManagedWorktree?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Worktrees", systemImage: "shippingbox")
                    .font(BrandFont.display(size: 15, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                
                Spacer()
                
                if !model.worktreesForCurrentProject.isEmpty {
                    Text("\(model.worktreesForCurrentProject.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(BrandColor.ion.opacity(0.2)))
                        .foregroundStyle(BrandColor.ion)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .background(BrandColor.orbit.opacity(0.3))
            
            // Worktree list
            if model.worktreesForCurrentProject.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No worktrees yet")
                        .font(BrandFont.ui(size: 14, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text("Create a worktree to start an agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.worktreesForCurrentProject) { worktree in
                            WorktreeListRow(
                                worktree: worktree,
                                isRunning: model.isSessionRunning(for: worktree),
                                isTerminalOpen: model.openTerminalTabs.contains(worktree.id),
                                onStart: {
                                    model.startAgent(for: worktree)
                                },
                                onStop: {
                                    model.stopAgent(for: worktree)
                                },
                                onOpenTerminal: {
                                    model.openTerminal(for: worktree)
                                },
                                onDelete: {
                                    pendingDelete = worktree
                                },
                                onRename: { newName in
                                    model.renameWorktree(worktree, to: newName)
                                }
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(BrandColor.midnight.opacity(0.5))
        .confirmationDialog(
            "Delete worktree?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let worktree = pendingDelete {
                    model.deleteWorktree(worktree)
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            if let worktree = pendingDelete {
                Text("This will remove \(worktree.displayName) and its agent branch.")
            }
        }
    }
}

/// Individual worktree row in the list
struct WorktreeListRow: View {
    let worktree: ManagedWorktree
    let isRunning: Bool
    let isTerminalOpen: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onOpenTerminal: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Bool
    
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var nameDraft = ""
    
    private var isNameValid: Bool {
        !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(isRunning ? BrandColor.mint : BrandColor.orbit.opacity(0.6))
                    .frame(width: 10, height: 10)
                
                // Name and branch
                VStack(alignment: .leading, spacing: 3) {
                    if isRenaming {
                        HStack(spacing: 6) {
                            TextField("Name", text: $nameDraft, onCommit: commitRename)
                                .textFieldStyle(.plain)
                                .font(BrandFont.ui(size: 14, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(BrandColor.ink)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(BrandColor.ion.opacity(0.5), lineWidth: 1)
                                )
                            
                            Button(action: commitRename) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(isNameValid ? BrandColor.mint : .secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isNameValid)
                            
                            Button(action: cancelRename) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(BrandColor.berry)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(worktree.displayName)
                                .font(BrandFont.ui(size: 14, weight: .semibold))
                                .foregroundStyle(BrandColor.flour)
                                .lineLimit(1)
                            
                            if isHovering {
                                Button {
                                    nameDraft = worktree.displayName
                                    isRenaming = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Label(worktree.originalBranch, systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        Text("•")
                            .foregroundStyle(.secondary)
                        
                        Text(isRunning ? "Running" : "Idle")
                            .font(.caption)
                            .foregroundStyle(isRunning ? BrandColor.mint : .secondary)
                    }
                }
                
                Spacer()
                
                // Terminal indicator
                if isTerminalOpen {
                    Image(systemName: "terminal")
                        .font(.caption)
                        .foregroundStyle(BrandColor.ion)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(BrandColor.ion.opacity(0.15))
                        )
                }
            }
            
            // Action buttons
            HStack(spacing: 8) {
                if isRunning {
                    Button {
                        onStop()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandDanger)
                    
                    Button {
                        onOpenTerminal()
                    } label: {
                        Label("Terminal", systemImage: "terminal")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandGhost)
                } else {
                    Button {
                        onStart()
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandPrimary)
                }
                
                Spacer()
                
                if isHovering && !isRunning {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.berry)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .fill(isHovering ? BrandColor.midnight : BrandColor.midnight.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .stroke(isTerminalOpen ? BrandColor.ion.opacity(0.4) : BrandColor.orbit.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func commitRename() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if onRename(trimmed) {
            isRenaming = false
        }
    }
    
    private func cancelRename() {
        isRenaming = false
        nameDraft = worktree.displayName
    }
}
