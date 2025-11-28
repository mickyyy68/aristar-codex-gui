import SwiftUI
import SwiftTerm

struct TerminalContainer: NSViewRepresentable {
    @ObservedObject var session: CodexSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)
        terminal.terminalDelegate = context.coordinator
        bindSessionOutput(to: terminal, coordinator: context.coordinator)
        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        nsView.terminalDelegate = context.coordinator
        if context.coordinator.session !== session {
            context.coordinator.session?.detachOutput()
            context.coordinator.session = session
            bindSessionOutput(to: nsView, coordinator: context.coordinator)
        }
    }

    static func dismantleNSView(_ nsView: TerminalView, coordinator: Coordinator) {
        coordinator.session?.detachOutput()
    }

    private func bindSessionOutput(to terminal: TerminalView, coordinator: Coordinator) {
        coordinator.session = session
        session.attachOutput { data in
            let slice = ArraySlice<UInt8>(data)
            terminal.feed(byteArray: slice)
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
