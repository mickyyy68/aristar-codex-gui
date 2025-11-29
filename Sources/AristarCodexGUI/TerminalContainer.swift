import SwiftUI
import SwiftTerm

struct TerminalContainer: NSViewRepresentable {
    @ObservedObject var session: CodexSession
    private static var viewCache: [UUID: TerminalView] = [:]

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> TerminalView {
        if let cached = Self.viewCache[session.id] {
            cached.terminalDelegate = context.coordinator
            bindSessionOutput(to: cached, coordinator: context.coordinator, replayExisting: false)
            return cached
        }

        let terminal = TerminalView(frame: .zero)
        terminal.terminalDelegate = context.coordinator
        bindSessionOutput(to: terminal, coordinator: context.coordinator, replayExisting: true)
        Self.viewCache[session.id] = terminal
        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        nsView.terminalDelegate = context.coordinator
        if context.coordinator.session !== session {
            context.coordinator.session?.detachOutput()
            context.coordinator.session = session
            bindSessionOutput(to: nsView, coordinator: context.coordinator, replayExisting: true)
        }
    }

    static func dismantleNSView(_ nsView: TerminalView, coordinator: Coordinator) {
        coordinator.session?.detachOutput()
    }

    private func bindSessionOutput(to terminal: TerminalView, coordinator: Coordinator, replayExisting: Bool) {
        coordinator.session = session
        session.attachOutput { data in
            let slice = ArraySlice<UInt8>(data)
            terminal.feed(byteArray: slice)
        }
        if replayExisting, !session.output.isEmpty, let data = session.output.data(using: .utf8) {
            // Defer to the next runloop tick so the view has a real size before replaying,
            // avoiding narrow (1-col) layouts.
            DispatchQueue.main.async {
                let slice = ArraySlice<UInt8>(data)
                terminal.feed(byteArray: slice)
            }
        }
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        weak var session: CodexSession?

        init(session: CodexSession) {
            self.session = session
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let buffer = Data(data)
            session?.send(data: buffer)
        }

        // Unused delegate callbacks for now.
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String : String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
