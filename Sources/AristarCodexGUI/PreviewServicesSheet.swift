import SwiftUI

/// Sheet for configuring and running preview services for a worktree
struct PreviewServicesSheet: View {
    @ObservedObject var model: AppModel
    let worktree: ManagedWorktree
    @Binding var isPresented: Bool
    
    @State private var services: [PreviewServiceConfig] = []
    @State private var editingService: PreviewServiceConfig?
    @State private var showAddService = false
    @State private var selectedServiceID: UUID?
    
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
            
            if services.isEmpty {
                // Empty state
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
                // Split view: service list on left, terminal on right
                HSplitView {
                    // Left: Service list
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(services) { service in
                                    PreviewServiceRow(
                                        service: service,
                                        isSelected: selectedServiceID == service.id,
                                        isRunning: model.isPreviewRunning(serviceID: service.id, worktree: worktree),
                                        onSelect: {
                                            selectedServiceID = service.id
                                        },
                                        onStart: {
                                            startService(service)
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
                            .padding(12)
                        }
                        
                        Divider()
                        
                        // Footer with actions
                        HStack {
                            Button {
                                showAddService = true
                            } label: {
                                Label("Add", systemImage: "plus")
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
                                        startAllServices()
                                    } label: {
                                        Label("Start All", systemImage: "play.fill")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.brandPrimary)
                                }
                            }
                        }
                        .padding(12)
                        .background(BrandColor.midnight)
                    }
                    .frame(minWidth: 280, maxWidth: 350)
                    .background(BrandColor.ink)
                    
                    // Right: Terminal output
                    VStack(spacing: 0) {
                        if let serviceID = selectedServiceID,
                           let session = model.previewSessions[worktree.id]?[serviceID],
                           session.isRunning {
                            // Show terminal for selected running service
                            VStack(spacing: 0) {
                                HStack {
                                    Circle()
                                        .fill(BrandColor.mint)
                                        .frame(width: 8, height: 8)
                                    Text(session.name)
                                        .font(BrandFont.ui(size: 13, weight: .semibold))
                                        .foregroundStyle(BrandColor.flour)
                                    Spacer()
                                    Button {
                                        model.stopPreviewService(serviceID, worktree: worktree)
                                    } label: {
                                        Label("Stop", systemImage: "stop.fill")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.brandDanger)
                                }
                                .padding(10)
                                .background(BrandColor.midnight)
                                
                                Divider()
                                
                                PreviewTerminalContainer(session: session)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        } else if let serviceID = selectedServiceID,
                                  let service = services.first(where: { $0.id == serviceID }) {
                            // Service selected but not running
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "terminal")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text(service.name.isEmpty ? "Service" : service.name)
                                    .font(BrandFont.ui(size: 15, weight: .semibold))
                                    .foregroundStyle(BrandColor.flour)
                                Text("Start the service to see output")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    startService(service)
                                } label: {
                                    Label("Start", systemImage: "play.fill")
                                }
                                .buttonStyle(.brandPrimary)
                                .disabled(!service.enabled)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // No service selected
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "terminal")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("Select a service")
                                    .font(BrandFont.ui(size: 15, weight: .semibold))
                                    .foregroundStyle(BrandColor.flour)
                                Text("Click on a service to view its output")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .background(BrandColor.ink.opacity(0.5))
                }
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
        .frame(minWidth: 700, minHeight: 500)
        .background(BrandColor.ink)
        .onAppear {
            loadServices()
            // Auto-select first service
            if selectedServiceID == nil {
                selectedServiceID = services.first?.id
            }
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
        selectedServiceID = service.id
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
        if selectedServiceID == service.id {
            selectedServiceID = services.first?.id
        }
    }
    
    private func toggleEnabled(_ service: PreviewServiceConfig, enabled: Bool) {
        if let idx = services.firstIndex(where: { $0.id == service.id }) {
            services[idx].enabled = enabled
            saveServices()
        }
    }
    
    private func startService(_ service: PreviewServiceConfig) {
        if let session = model.startPreviewService(service, worktree: worktree) {
            selectedServiceID = service.id
            // The session will be started when the terminal view is displayed
            _ = session // Keep reference
        }
    }
    
    private func startAllServices() {
        model.startPreview(for: worktree, services: services)
        // Select first enabled service
        if let first = services.first(where: { $0.enabled }) {
            selectedServiceID = first.id
        }
    }
}

/// Row for a single preview service
private struct PreviewServiceRow: View {
    let service: PreviewServiceConfig
    let isSelected: Bool
    let isRunning: Bool
    let onSelect: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleEnabled: (Bool) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Status indicator
                    Circle()
                        .fill(isRunning ? BrandColor.mint : (service.enabled ? BrandColor.orbit.opacity(0.6) : BrandColor.orbit.opacity(0.3)))
                        .frame(width: 8, height: 8)
                    
                    // Service name
                    Text(service.name.isEmpty ? "Unnamed Service" : service.name)
                        .font(BrandFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(service.enabled ? BrandColor.flour : BrandColor.flour.opacity(0.5))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Quick action buttons
                    if isHovering || isSelected {
                        if isRunning {
                            Button(action: onStop) {
                                Image(systemName: "stop.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(BrandColor.berry)
                        } else {
                            Button(action: onStart) {
                                Image(systemName: "play.fill")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(service.enabled ? BrandColor.mint : .secondary)
                            .disabled(!service.enabled)
                        }
                        
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(isRunning)
                        
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(BrandColor.berry.opacity(isRunning ? 0.3 : 1))
                        .disabled(isRunning)
                    }
                }
                
                // Command preview
                Text(service.command)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .fill(isSelected ? BrandColor.ion.opacity(0.15) : (isHovering ? BrandColor.midnight : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.sm, style: .continuous)
                    .stroke(isSelected ? BrandColor.ion.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
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
