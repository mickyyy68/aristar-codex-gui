import SwiftUI
import SwiftTerm
import AppKit

struct TerminalContainer: NSViewRepresentable {
    @ObservedObject var session: CodexSession
    private static var viewCache: [UUID: TerminalView] = [:]

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeNSView(context: Context) -> TerminalView {
        // Cached view path: reattach without replaying history.
        if let cached = Self.viewCache[session.id] {
            cached.terminalDelegate = context.coordinator
            applyTheme(to: cached)
            bindSessionOutput(to: cached, coordinator: context.coordinator, replayExisting: false)
            return cached
        }

        // New view path.
        let terminal = TerminalView(frame: .zero)
        terminal.translatesAutoresizingMaskIntoConstraints = true
        terminal.wantsLayer = true
        applyTheme(to: terminal)
        terminal.terminalDelegate = context.coordinator
        Self.viewCache[session.id] = terminal
        bindSessionOutput(to: terminal, coordinator: context.coordinator, replayExisting: true)
        return terminal
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {
        nsView.terminalDelegate = context.coordinator
        applyTheme(to: nsView)
        if context.coordinator.session !== session {
            context.coordinator.session?.detachOutput()
            context.coordinator.session = session
            bindSessionOutput(to: nsView, coordinator: context.coordinator, replayExisting: true)
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

    private func bindSessionOutput(to terminal: TerminalView, coordinator: Coordinator, replayExisting: Bool) {
        coordinator.session = session
        coordinator.terminal = terminal
        if replayExisting {
            coordinator.resetSessionState()
        }
        coordinator.installFrameObserver(on: terminal)
        DispatchQueue.main.async { [weak coordinator] in
            coordinator?.handleSize(from: terminal, shouldReplay: replayExisting)
        }
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        weak var session: CodexSession?
        weak var terminal: TerminalView?
        private var frameObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
        private var hasStartedSession = false

        init(session: CodexSession) {
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
            guard cols > 10, rows > 2 else { return }
            let safeRows = max(1, rows - 1)

            print("DEBUG: View reported \(cols)x\(rows). Resizing PTY to SAFE size: \(cols)x\(safeRows)")

            DispatchQueue.main.async { [weak self] in
                guard let self = self, let session = self.session else { return }

                if self.hasStartedSession {
                    session.attachOutput { [weak self] data in
                        self?.feedTerminal(data)
                    }
                    session.updateWindowSize(cols: cols, rows: safeRows)
                    return
                }

                self.hasStartedSession = true

                session.attachOutput { [weak self] data in
                    self?.feedTerminal(data)
                }

                session.start(initialCols: cols, initialRows: safeRows)

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
