import Foundation
import Combine
import Darwin

final class PreviewServiceSession: ObservableObject, Identifiable {
    let id = UUID()
    let serviceID: UUID
    let name: String
    let command: String
    let workingDirectory: URL
    let envText: String?

    @Published var output: Data = Data()
    @Published var inputBuffer: String = ""
    @Published var isRunning: Bool = false

    var onExit: (() -> Void)?

    private var process: Process?
    private var ptyMaster: FileHandle?
    private var ptySlave: FileHandle?
    private var outputHandler: ((Data) -> Void)?
    private var hasStarted = false
    private var envFileURL: URL?
    private var envBackupURL: URL?
    private var createdEnvFile = false
    private var startTime: Date?
    
    /// Minimum time the session should stay visible so users can see errors
    private static let minimumUptime: TimeInterval = 5.0

    init(serviceID: UUID, name: String, command: String, workingDirectory: URL, envText: String?) {
        self.serviceID = serviceID
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.envText = envText
    }

    deinit {
        stop()
    }

    func start(initialCols: Int, initialRows: Int) {
        print("[preview] start() called name=\(name) cols=\(initialCols) rows=\(initialRows)")
        guard !hasStarted else {
            print("[preview] already started, just updating window size")
            updateWindowSize(cols: initialCols, rows: initialRows)
            return
        }
        hasStarted = true

        guard let (master, slave) = Self.openPty(cols: initialCols, rows: initialRows) else {
            print("[preview] ERROR: failed to allocate PTY")
            Task { @MainActor in
                if let data = "\n[Failed to allocate preview terminal]\n".data(using: .utf8) {
                    self.output.append(data)
                }
            }
            return
        }
        print("[preview] PTY allocated successfully")

        prepareEnvFile()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.currentDirectoryURL = workingDirectory

        let escapedRoot = Self.shellEscape(workingDirectory.path)
        let startCommand = "cd \(escapedRoot) && \(command)"
        print("[preview] command: \(startCommand)")
        print("[preview] workingDirectory: \(workingDirectory.path)")
        proc.arguments = ["-l", "-c", startCommand]
        proc.standardInput = slave
        proc.standardOutput = slave
        proc.standardError = slave

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["COLUMNS"] = "\(initialCols)"
        env["LINES"] = "\(initialRows)"
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

        proc.terminationHandler = { [weak self] proc in
            print("[preview] process terminated status=\(proc.terminationStatus)")
            Task { @MainActor in
                guard let self else { return }
                self.isRunning = false
                self.cleanupEnvFile()
                
                // Ensure minimum uptime so user can see error output
                let elapsed = self.startTime.map { Date().timeIntervalSince($0) } ?? 0
                let remaining = max(0, Self.minimumUptime - elapsed)
                
                if remaining > 0 {
                    // Append exit message so user knows what happened
                    let exitMsg = "\n\n[Process exited with status \(proc.terminationStatus). Closing in \(Int(remaining))s...]\n"
                    if let data = exitMsg.data(using: .utf8) {
                        self.output.append(data)
                        self.outputHandler?(data)
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                }
                
                self.onExit?()
            }
        }

        do {
            try proc.run()
            process = proc
            ptyMaster = master
            ptySlave = slave
            startTime = Date()
            print("[preview] process started pid=\(proc.processIdentifier)")
            Task { @MainActor in self.isRunning = true }
        } catch {
            print("[preview] ERROR: failed to run process: \(error)")
            Task { @MainActor in
                let errorMsg = "\n[Failed to start \(self.name): \(error.localizedDescription)]\n"
                if let data = errorMsg.data(using: .utf8) {
                    self.output.append(data)
                }
                self.cleanupEnvFile()
                self.isRunning = false
                self.onExit?()
            }
        }
    }

    func stop() {
        ptyMaster?.readabilityHandler = nil
        defer { cleanupEnvFile() }

        guard let proc = process else { return }
        let pid = proc.processIdentifier
        kill(pid, SIGINT)

        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if proc.isRunning {
                kill(pid, SIGKILL)
            }
            self.process = nil
            self.ptyMaster = nil
            self.ptySlave = nil
            Task { @MainActor in
                self.isRunning = false
            }
        }
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
            print("[preview] Failed to write to preview PTY: \(error)")
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

    private func prepareEnvFile() {
        guard let envText, !envText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let envURL = workingDirectory.appendingPathComponent(".env")
        envFileURL = envURL
        let backup = envURL.appendingPathExtension("codex-backup")
        if FileManager.default.fileExists(atPath: envURL.path) {
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: envURL, to: backup)
            envBackupURL = backup
        }
        try? envText.write(to: envURL, atomically: true, encoding: .utf8)
        createdEnvFile = true
    }

    private func cleanupEnvFile() {
        defer {
            envBackupURL = nil
            envFileURL = nil
            createdEnvFile = false
        }
        guard let envURL = envFileURL else { return }
        if createdEnvFile {
            try? FileManager.default.removeItem(at: envURL)
        }
        if let backup = envBackupURL, FileManager.default.fileExists(atPath: backup.path) {
            try? FileManager.default.moveItem(at: backup, to: envURL)
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
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }
}
