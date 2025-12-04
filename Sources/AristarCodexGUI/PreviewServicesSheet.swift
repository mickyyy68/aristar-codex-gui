import SwiftUI

/// Sheet for configuring and running preview services for a worktree
struct PreviewServicesSheet: View {
    @ObservedObject var model: AppModel
    let worktree: ManagedWorktree
    @Binding var isPresented: Bool
    
    @State private var services: [PreviewServiceConfig] = []
    @State private var editingService: PreviewServiceConfig?
    @State private var showAddService = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview Services")
                        .font(BrandFont.display(size: 18, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text(worktree.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(BrandColor.midnight)
            
            Divider()
            
            // Services list
            if services.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No services configured")
                        .font(BrandFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(BrandColor.flour)
                    Text("Add a service to run previews alongside your agent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showAddService = true
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(.brandPrimary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(services) { service in
                            PreviewServiceRow(
                                service: service,
                                isRunning: model.isPreviewRunning(serviceID: service.id, worktree: worktree),
                                onStart: {
                                    _ = model.startPreviewService(service, worktree: worktree)
                                },
                                onStop: {
                                    model.stopPreviewService(service.id, worktree: worktree)
                                },
                                onEdit: {
                                    editingService = service
                                },
                                onDelete: {
                                    deleteService(service)
                                },
                                onToggleEnabled: { enabled in
                                    toggleEnabled(service, enabled: enabled)
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Footer with actions
                HStack {
                    Button {
                        showAddService = true
                    } label: {
                        Label("Add Service", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandGhost)
                    
                    Spacer()
                    
                    if services.contains(where: { $0.enabled }) {
                        if model.isPreviewRunning(for: worktree) {
                            Button {
                                model.stopPreview(for: worktree)
                            } label: {
                                Label("Stop All", systemImage: "stop.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.brandDanger)
                        } else {
                            Button {
                                model.startPreview(for: worktree, services: services)
                            } label: {
                                Label("Start All", systemImage: "play.fill")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.brandPrimary)
                        }
                    }
                }
                .padding()
                .background(BrandColor.midnight)
            }
            
            // Error display
            if let error = model.previewError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(BrandColor.citrus)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(BrandColor.flour)
                    Spacer()
                }
                .padding()
                .background(BrandColor.citrus.opacity(0.15))
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(BrandColor.ink)
        .onAppear {
            loadServices()
        }
        .sheet(isPresented: $showAddService) {
            ServiceEditorSheet(
                service: PreviewServiceConfig(),
                isNew: true,
                onSave: { service in
                    addService(service)
                    showAddService = false
                },
                onCancel: {
                    showAddService = false
                }
            )
        }
        .sheet(item: $editingService) { service in
            ServiceEditorSheet(
                service: service,
                isNew: false,
                onSave: { updated in
                    updateService(updated)
                    editingService = nil
                },
                onCancel: {
                    editingService = nil
                }
            )
        }
    }
    
    private func loadServices() {
        guard let project = model.currentProject else { return }
        services = model.previewConfigs(for: worktree, project: project)
    }
    
    private func saveServices() {
        guard let project = model.currentProject else { return }
        _ = model.savePreviewConfigs(services, for: worktree, project: project)
    }
    
    private func addService(_ service: PreviewServiceConfig) {
        services.append(service)
        saveServices()
    }
    
    private func updateService(_ service: PreviewServiceConfig) {
        if let idx = services.firstIndex(where: { $0.id == service.id }) {
            services[idx] = service
            saveServices()
        }
    }
    
    private func deleteService(_ service: PreviewServiceConfig) {
        model.stopPreviewService(service.id, worktree: worktree)
        services.removeAll { $0.id == service.id }
        saveServices()
    }
    
    private func toggleEnabled(_ service: PreviewServiceConfig, enabled: Bool) {
        if let idx = services.firstIndex(where: { $0.id == service.id }) {
            services[idx].enabled = enabled
            saveServices()
        }
    }
}

/// Row for a single preview service
private struct PreviewServiceRow: View {
    let service: PreviewServiceConfig
    let isRunning: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: (Bool) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Status indicator
                Circle()
                    .fill(isRunning ? BrandColor.mint : (service.enabled ? BrandColor.orbit.opacity(0.6) : BrandColor.orbit.opacity(0.3)))
                    .frame(width: 10, height: 10)
                
                // Service info
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name.isEmpty ? "Unnamed Service" : service.name)
                        .font(BrandFont.ui(size: 14, weight: .semibold))
                        .foregroundStyle(service.enabled ? BrandColor.flour : BrandColor.flour.opacity(0.5))
                    
                    Text(service.command)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Enabled toggle
                Toggle("", isOn: Binding(
                    get: { service.enabled },
                    set: { onToggleEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isRunning)
            }
            
            // Actions row
            HStack(spacing: 8) {
                if isRunning {
                    Button(action: onStop) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandDanger)
                } else {
                    Button(action: onStart) {
                        Label("Start", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(!service.enabled)
                }
                
                Spacer()
                
                if isHovering && !isRunning {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(BrandColor.berry)
                }
            }
            
            // Show root path if set
            if !service.rootPath.isEmpty {
                Label(service.rootPath, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .fill(isHovering ? BrandColor.midnight : BrandColor.midnight.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .stroke(isRunning ? BrandColor.mint.opacity(0.4) : BrandColor.orbit.opacity(0.2), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

/// Sheet for editing a service configuration
private struct ServiceEditorSheet: View {
    @State var service: PreviewServiceConfig
    let isNew: Bool
    let onSave: (PreviewServiceConfig) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "Add Service" : "Edit Service")
                    .font(BrandFont.display(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(BrandColor.midnight)
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Service Name")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g., Frontend Dev Server", text: $service.name)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(BrandColor.midnight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Command
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Command")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("e.g., npm run dev", text: $service.command)
                            .textFieldStyle(.plain)
                            .font(.system(.body, design: .monospaced))
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(BrandColor.midnight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Root path
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Root Path (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Relative path from worktree root, leave empty for worktree root")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        TextField("e.g., frontend/", text: $service.rootPath)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(BrandColor.midnight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Env text
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Environment Variables (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Will be written to .env file before starting")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        TextEditor(text: $service.envText)
                            .font(.system(.caption, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 80)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(BrandColor.midnight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(BrandColor.orbit.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    // Enabled toggle
                    Toggle(isOn: $service.enabled) {
                        Text("Enabled")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .toggleStyle(.switch)
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.brandGhost)
                
                Spacer()
                
                Button(isNew ? "Add Service" : "Save") {
                    onSave(service)
                }
                .buttonStyle(.brandPrimary)
                .disabled(service.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(BrandColor.midnight)
        }
        .frame(minWidth: 400, minHeight: 450)
        .background(BrandColor.ink)
    }
}
