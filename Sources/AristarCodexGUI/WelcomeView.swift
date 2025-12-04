import SwiftUI

/// Welcome view shown when no project is open
struct WelcomeView: View {
    @ObservedObject var model: AppModel
    @State private var isHoveringOpen = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Logo and title
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(BrandColor.ion.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(BrandColor.ion.opacity(0.25))
                        .frame(width: 60, height: 60)
                    Image(systemName: "atom")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BrandColor.ion)
                }
                
                Text("Aristar Codex")
                    .font(BrandFont.display(size: 28, weight: .bold))
                    .foregroundStyle(BrandColor.flour)
                
                Text("Open a project to get started")
                    .font(BrandFont.ui(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            
            // Open folder button
            Button {
                openFolderPicker()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open Project Folder")
                        .font(BrandFont.ui(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .buttonStyle(.brandPrimary)
            .scaleEffect(isHoveringOpen ? 1.02 : 1.0)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringOpen = hovering
                }
            }
            
            // Recent projects
            if !model.favorites.isEmpty || !model.recents.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Rectangle()
                            .fill(BrandColor.orbit.opacity(0.4))
                            .frame(height: 1)
                        Text("or select a project")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(BrandColor.orbit.opacity(0.4))
                            .frame(height: 1)
                    }
                    .frame(maxWidth: 400)
                    
                    VStack(spacing: 8) {
                        if !model.favorites.isEmpty {
                            ForEach(model.favorites.prefix(3)) { project in
                                WelcomeProjectRow(project: project, isFavorite: true) {
                                    model.openProject(project)
                                }
                            }
                        }
                        
                        ForEach(model.recents.prefix(model.favorites.isEmpty ? 5 : 3)) { project in
                            WelcomeProjectRow(project: project, isFavorite: false) {
                                model.openProject(project)
                            }
                        }
                    }
                    .frame(maxWidth: 400)
                }
            }
            
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func openFolderPicker() {
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

private struct WelcomeProjectRow: View {
    let project: ProjectRef
    let isFavorite: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isFavorite ? "star.fill" : "folder")
                    .foregroundStyle(isFavorite ? BrandColor.ion : BrandColor.flour.opacity(0.7))
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(BrandFont.ui(size: 14, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                        .lineLimit(1)
                    
                    Text(project.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(isHovering ? 1 : 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                    .fill(isHovering ? BrandColor.midnight : BrandColor.midnight.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                    .stroke(isHovering ? BrandColor.ion.opacity(0.3) : BrandColor.orbit.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
