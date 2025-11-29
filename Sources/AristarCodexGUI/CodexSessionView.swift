import SwiftUI
import SwiftTerm

struct CodexSessionView: View {
    @ObservedObject var session: CodexSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.title).font(.headline)
                Spacer()
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(session.isRunning ? .green : .red)
                Button {
                    onClose()
                } label: {
                    Label("Close", systemImage: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            GeometryReader { proxy in
                TerminalContainer(session: session)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}
