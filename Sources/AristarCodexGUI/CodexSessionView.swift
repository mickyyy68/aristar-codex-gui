import SwiftUI
import SwiftTerm

struct CodexSessionView: View {
    @ObservedObject var session: CodexSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(BrandColor.ion)
                Text(session.title)
                    .font(BrandFont.display(size: 16, weight: .semibold))
                    .foregroundStyle(BrandColor.flour)
                Spacer()
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(session.isRunning ? BrandColor.mint : BrandColor.berry)
                Button {
                    onClose()
                } label: {
                    Label("Close", systemImage: "xmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.brandGhost)
            }
            .padding()
            .background(BrandColor.midnight.opacity(0.85))

            Divider()
                .overlay(BrandColor.orbit.opacity(0.4))

            GeometryReader { proxy in
                TerminalContainer(session: session)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(BrandColor.ink)
            }
        }
        .brandPanel()
        .brandShadow()
        .edgesIgnoringSafeArea(.bottom)
    }
}
