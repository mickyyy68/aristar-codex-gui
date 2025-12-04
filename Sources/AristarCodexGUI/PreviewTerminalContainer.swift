import SwiftUI
import SwiftTerm
import AppKit

struct PreviewTerminalContainer: NSViewRepresentable {
    @ObservedObject var session: PreviewServiceSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> TerminalView {
        let terminal = TerminalView(frame: .zero)
        terminal.translatesAutoresizingMaskIntoConstraints = true
        terminal.wantsLayer = true
        applyTheme(to: terminal)
        terminal.terminalDelegate = context.coordinator
        context.coordinator.terminal = terminal
        context.coordinator.installFrameObserver(on: terminal)
        DispatchQueue.main.async { [weak coordinator = context.coordinator, weak terminal] in
            guard let coordinator, let terminal else { return }
            coordinator.handleSize(from: terminal, shouldReplay: true)
        }
        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        nsView.terminalDelegate = context.coordinator
        context.coordinator.terminal = nsView
        applyTheme(to: nsView)
        if context.coordinator.session !== session {
            context.coordinator.session?.detachOutput()
            context.coordinator.session = session
            context.coordinator.resetSessionState()
            context.coordinator.handleSize(from: nsView, shouldReplay: true)
        } else if context.coordinator.hasStartedSession == false {
            context.coordinator.handleSize(from: nsView, shouldReplay: true)
        }
    }

    private func applyTheme(to terminal: TerminalView) {
        terminal.nativeBackgroundColor = NSColor(BrandColor.ink)
        terminal.nativeForegroundColor = NSColor(BrandColor.flour)
        terminal.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    }

    static func dismantleNSView(_ nsView: TerminalView, coordinator: Coordinator) {
        coordinator.removeFrameObserver(for: nsView)
        coordinator.session?.detachOutput()
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        weak var session: PreviewServiceSession?
        weak var terminal: TerminalView?
        private var frameObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
        fileprivate var hasStartedSession = false

        init(session: PreviewServiceSession) {
            self.session = session
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let buffer = Data(data)
            session?.send(data: buffer)
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            handleSize(cols: newCols, rows: newRows, shouldReplay: false)
        }

        func installFrameObserver(on terminal: TerminalView) {
            let key = ObjectIdentifier(terminal)
            guard frameObservers[key] == nil else { return }
            terminal.postsFrameChangedNotifications = true
            let token = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: terminal,
                queue: .main
            ) { [weak self, weak terminal] _ in
                guard let self, let terminal else { return }
                self.handleSize(from: terminal, shouldReplay: false)
            }
            frameObservers[key] = token
        }

        func removeFrameObserver(for terminal: TerminalView) {
            let key = ObjectIdentifier(terminal)
            if let token = frameObservers.removeValue(forKey: key) {
                NotificationCenter.default.removeObserver(token)
            }
        }

        fileprivate func resetSessionState() {
            hasStartedSession = false
        }

        fileprivate func handleSize(from terminal: TerminalView, shouldReplay: Bool) {
            let term = terminal.getTerminal()
            handleSize(cols: term.cols, rows: term.rows, shouldReplay: shouldReplay)
        }

        private func handleSize(cols: Int, rows: Int, shouldReplay: Bool) {
            print("[PreviewTerminal] handleSize cols=\(cols) rows=\(rows) shouldReplay=\(shouldReplay)")
            guard cols > 10, rows > 2 else {
                print("[PreviewTerminal] size too small, skipping")
                return
            }
            let safeRows = max(1, rows - 1)

            DispatchQueue.main.async { [weak self] in
                guard let self = self, let session = self.session else {
                    print("[PreviewTerminal] no self or session in async block")
                    return
                }

                print("[PreviewTerminal] hasStartedSession=\(self.hasStartedSession) session.isRunning=\(session.isRunning)")

                if self.hasStartedSession {
                    session.attachOutput { [weak self] data in
                        self?.feedTerminal(data)
                    }
                    session.updateWindowSize(cols: cols, rows: safeRows)
                    if shouldReplay, !session.output.isEmpty {
                        self.feedTerminal(session.output)
                    }
                    return
                }

                self.hasStartedSession = true
                print("[PreviewTerminal] starting session with cols=\(cols) rows=\(safeRows)")

                session.attachOutput { [weak self] data in
                    self?.feedTerminal(data)
                }

                session.start(initialCols: cols, initialRows: safeRows)
                print("[PreviewTerminal] session.start() called, isRunning=\(session.isRunning)")

                if shouldReplay, !session.output.isEmpty {
                    self.feedTerminal(session.output)
                }
            }
        }

        private func feedTerminal(_ data: Data) {
            guard let terminal = terminal else { return }
            let slice = ArraySlice<UInt8>(data)
            if Thread.isMainThread {
                terminal.feed(byteArray: slice)
            } else {
                DispatchQueue.main.async {
                    terminal.feed(byteArray: slice)
                }
            }
        }

        // Unused delegate callbacks.
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
