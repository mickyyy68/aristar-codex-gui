import Foundation
import Combine
import Darwin

final class CodexSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String
    let codexPath: String
    let workingDirectory: URL
    let originalBranch: String?
    let agentBranch: String?
    let shouldResume: Bool

    @Published var output: Data = Data()
    @Published var inputBuffer: String = ""
    @Published var isRunning: Bool = false

    private var process: Process?
    private var ptyMaster: FileHandle?
    private var ptySlave: FileHandle?
    private var outputHandler: ((Data) -> Void)?
    private var hasStarted: Bool = false

    init(
        title: String,
        codexPath: String,
        workingDirectory: URL,
        originalBranch: String? = nil,
        agentBranch: String? = nil,
        shouldResume: Bool = false
    ) {
        self.title = title
        self.codexPath = codexPath
        self.workingDirectory = workingDirectory
        self.originalBranch = originalBranch
        self.agentBranch = agentBranch
        self.shouldResume = shouldResume
    }

    deinit {
        stop()
    }

    func start(initialCols: Int, initialRows: Int) {
        guard !hasStarted else {
            updateWindowSize(cols: initialCols, rows: initialRows)
            return
        }
        hasStarted = true

        guard let (master, slave) = Self.openPty(cols: initialCols, rows: initialRows) else {
            Task { @MainActor in
                if let data = "\n[Failed to allocate pseudo-terminal]\n".data(using: .utf8) {
                    self.output.append(data)
                }
            }
            return
        }

        let proc = Process()

        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.currentDirectoryURL = workingDirectory
        let escapedPath = Self.shellEscape(workingDirectory.path)
        let escapedCodex = Self.shellEscape(codexPath)
        let codexCommand: String
        if shouldResume {
            codexCommand = "cd \(escapedPath) && \(escapedCodex) resume"
        } else {
            codexCommand = "cd \(escapedPath) && \(escapedCodex) --cd \(escapedPath)"
        }
        // Run Codex, then drop into a login shell for interactive use.
        proc.arguments = ["-l", "-c", "\(codexCommand); exec zsh -l"]
        proc.standardInput = slave
        proc.standardOutput = slave
        proc.standardError = slave

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env.removeValue(forKey: "TERM_PROGRAM")
        env.removeValue(forKey: "TERM_PROGRAM_VERSION")
        env.removeValue(forKey: "GHOSTTY_RESOURCES_DIR")
        env.removeValue(forKey: "COLORTERM")
        env.removeValue(forKey: "XPC_SERVICE_NAME")
        env["COLUMNS"] = "\(initialCols)"
        env["LINES"] = "\(initialRows)"

        print("----------- DEBUG SESSION START -----------")
        print("1. Intended Size: \(initialCols)x\(initialRows)")
        print("2. Environment TERM being sent: \(env["TERM"] ?? "NIL")")
        print("3. Executable: \(proc.executableURL?.path ?? "NIL")")
        print("4. Arguments: \(proc.arguments ?? [])")
        print("-------------------------------------------")
        proc.environment = env

        master.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }

            Task { @MainActor in
                self.output.append(data)
                self.outputHandler?(data)
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
            }
        }

        do {
            try proc.run()
            process = proc
            ptyMaster = master
            ptySlave = slave
            Task { @MainActor in self.isRunning = true }
        } catch {
            Task { @MainActor in
                let errorMsg = "\n[Failed to start Codex: \(error.localizedDescription)]\n"
                if let data = errorMsg.data(using: .utf8) {
                    self.output.append(data)
                }
                self.isRunning = false
            }
        }
    }

    func stop() {
        ptyMaster?.readabilityHandler = nil
        process?.terminate()
        process = nil
        ptyMaster = nil
        ptySlave = nil
        isRunning = false
    }

    func sendCurrentInput() {
        let trimmed = inputBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        send(line: trimmed)
        inputBuffer = ""
    }

    func send(line: String) {
        let message = line + "\n"
        if let data = message.data(using: .utf8) {
            send(data: data)
        }
    }

    func send(data: Data) {
        guard let master = ptyMaster else { return }
        do {
            try master.write(contentsOf: data)
        } catch {
            // Swallow write errors to avoid crashing when the child closes the PTY.
            print("Failed to write to PTY: \(error)")
        }
    }

    func attachOutput(_ handler: @escaping (Data) -> Void) {
        outputHandler = handler
    }

    func detachOutput() {
        outputHandler = nil
    }

    func updateWindowSize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, let master = ptyMaster else { return }
        var size = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(master.fileDescriptor, TIOCSWINSZ, &size)
        if let pid = process?.processIdentifier {
            _ = Darwin.kill(pid, SIGWINCH)
        }
    }

    private static func openPty(cols: Int, rows: Int) -> (FileHandle, FileHandle)? {
        var master: Int32 = 0
        var slave: Int32 = 0
        var size = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
        let result = openpty(&master, &slave, nil, nil, &size)
        guard result == 0 else { return nil }

        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        return (masterHandle, slaveHandle)
    }

    private static func shellEscape(_ value: String) -> String {
        // Single-quote the string and escape embedded single quotes for POSIX shells.
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
}
