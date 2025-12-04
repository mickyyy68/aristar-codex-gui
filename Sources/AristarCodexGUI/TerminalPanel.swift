import SwiftUI

/// Right panel with tabbed terminals for running agents
struct TerminalPanel: View {
    @ObservedObject var model: AppModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TerminalTabBar(model: model)
            
            Divider()
                .background(BrandColor.orbit.opacity(0.3))
            
            // Terminal content
            if let activeID = model.activeTerminalID,
               let worktree = model.worktreeByID(activeID) {
                VStack(alignment: .leading, spacing: 0) {
                    // Metadata bar
                    TerminalMetadataBar(
                        worktree: worktree,
                        isRunning: model.isSessionRunning(for: worktree),
                        onStop: {
                            model.stopAgent(for: worktree)
                        },
                        onResume: {
                            model.resumeAgent(for: worktree)
                        },
                        onCopyPath: {
                            copyPath(worktree.path.path)
                        }
                    )
                    
                    Divider()
                        .background(BrandColor.orbit.opacity(0.3))
                    
                    // Terminal view
                    if let session = model.sessionForWorktree(worktree) {
                        CodexSessionView(session: session) {
                            model.stopAgent(for: worktree)
                        }
                    } else {
                        // No session running
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "terminal")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No agent running")
                                .font(BrandFont.ui(size: 15, weight: .semibold))
                                .foregroundStyle(BrandColor.flour)
                            Text("Start the agent to see output here")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                model.startAgent(for: worktree)
                            } label: {
                                Label("Start Agent", systemImage: "play.fill")
                            }
                            .buttonStyle(.brandPrimary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                // No active tab
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "terminal")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Select a terminal tab")
                        .font(BrandFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(BrandColor.midnight.opacity(0.5))
    }
}

/// Tab bar for terminal panel
private struct TerminalTabBar: View {
    @ObservedObject var model: AppModel
    
    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(model.openTerminalTabs, id: \.self) { worktreeID in
                        if let worktree = model.worktreeByID(worktreeID) {
                            TerminalTab(
                                worktree: worktree,
                                isActive: model.activeTerminalID == worktreeID,
                                isRunning: model.isSessionRunning(for: worktree),
                                onSelect: {
                                    model.activeTerminalID = worktreeID
                                },
                                onClose: {
                                    model.closeTerminal(worktreeID)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            
            Spacer()
            
            // Panel controls
            HStack(spacing: 8) {
                Button {
                    model.closeAllTerminals()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close all terminals")
            }
            .padding(.horizontal, 12)
        }
        .background(BrandColor.ink.opacity(0.5))
    }
}

/// Individual terminal tab
private struct TerminalTab: View {
    let worktree: ManagedWorktree
    let isActive: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? BrandColor.mint : BrandColor.orbit.opacity(0.6))
                    .frame(width: 8, height: 8)
                
                Text(worktree.displayName)
                    .font(BrandFont.ui(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? BrandColor.flour : BrandColor.flour.opacity(0.7))
                    .lineLimit(1)
                
                if isHovering || isActive {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .fill(isActive ? BrandColor.midnight : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .stroke(isActive ? BrandColor.ion.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

/// Metadata bar showing worktree info and actions
private struct TerminalMetadataBar: View {
    let worktree: ManagedWorktree
    let isRunning: Bool
    let onStop: () -> Void
    let onResume: () -> Void
    let onCopyPath: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Worktree info
            VStack(alignment: .leading, spacing: 2) {
                Text(worktree.displayName)
                    .font(BrandFont.ui(size: 14, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                
                HStack(spacing: 8) {
                    Label(worktree.originalBranch, systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    Text(isRunning ? "Running" : "Idle")
                        .font(.caption)
                        .foregroundStyle(isRunning ? BrandColor.mint : .secondary)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isRunning {
                    Button(action: onStop) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandDanger)
                    
                    Button(action: onResume) {
                        Label("Resume", systemImage: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandGhost)
                } else {
                    Button {
                        // Start will be handled by parent
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandPrimary)
                }
                
                Button(action: onCopyPath) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.brandGhost)
                .help("Copy path")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(BrandColor.ink.opacity(0.3))
    }
}

/// Helper to copy path to clipboard
func copyPath(_ path: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(path, forType: .string)
}
