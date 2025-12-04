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
            
            if model.currentProject == nil {
                WelcomeView(model: model)
            } else {
                VStack(spacing: 0) {
                    ProjectHeader(model: model)
                    
                    if let error = model.hubError {
                        BannerView(
                            text: error,
                            systemImage: "exclamationmark.triangle.fill",
                            tint: BrandColor.citrus
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    
                    // Main split view
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            // Left panel: Worktree list
                            WorktreeListPanel(model: model)
                                .frame(width: max(280, geometry.size.width * 0.3))
                            
                            Divider()
                                .background(BrandColor.orbit.opacity(0.3))
                            
                            // Right panel: Terminal (or empty state)
                            if model.hasOpenTerminals {
                                TerminalPanel(model: model)
                                    .frame(maxWidth: .infinity)
                            } else {
                                EmptyTerminalPlaceholder()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Placeholder shown when no terminals are open
private struct EmptyTerminalPlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(BrandColor.orbit.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "terminal")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }
            
            Text("No terminals open")
                .font(BrandFont.ui(size: 16, weight: .semibold))
                .foregroundStyle(BrandColor.flour)
            
            Text("Start an agent to see its terminal here")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandColor.midnight.opacity(0.3))
    }
}

/// Banner for displaying errors/warnings
struct BannerView: View {
    let text: String
    let systemImage: String
    let tint: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(BrandColor.flour)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .fill(tint.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandRadius.md, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Pill and Card Styles (kept from original)

struct ActionPill<Content: View>: View {
    var fill: Color = BrandColor.midnight.opacity(0.85)
    var stroke: Color = BrandColor.orbit.opacity(0.35)
    var foreground: Color = BrandColor.flour
    var padding: EdgeInsets = EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
    let action: () -> Void
    @ViewBuilder let label: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
            }
            .font(BrandFont.ui(size: 13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(padding)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
