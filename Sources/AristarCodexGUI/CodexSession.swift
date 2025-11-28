import Foundation
import Combine
import Darwin

final class CodexSession: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let codexPath: String
    let workingDirectory: URL
    let originalBranch: String?
    let agentBranch: String?

    @Published var output: String = ""
    @Published var inputBuffer: String = ""
    @Published var isRunning: Bool = false

    private var process: Process?
    private var ptyMaster: FileHandle?
    private var ptySlave: FileHandle?
    private var outputHandler: ((Data) -> Void)?

    init(
        title: String,
        codexPath: String,
        workingDirectory: URL,
        originalBranch: String? = nil,
        agentBranch: String? = nil
    ) {
        self.title = title
        self.codexPath = codexPath
        self.workingDirectory = workingDirectory
        self.originalBranch = originalBranch
        self.agentBranch = agentBranch
        start()
    }

    deinit {
        stop()
    }

    private func start() {
        guard let (master, slave) = Self.openPty() else {
            Task { @MainActor in
                self.output.append("\n[Failed to allocate pseudo-terminal]\n")
            }
            return
        }

        let proc = Process()

        proc.executableURL = URL(fileURLWithPath: codexPath)
        proc.arguments = ["--cd", workingDirectory.path]
        proc.standardInput = slave
        proc.standardOutput = slave
        proc.standardError = slave
        var env = ProcessInfo.processInfo.environment
        env["TERM"] = env["TERM"] ?? "xterm-256color"
        proc.environment = env

        master.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty else { return }

            Task { @MainActor in
                if let chunk = String(data: data, encoding: .utf8) {
                    self.output.append(chunk)
                }
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
                self.output.append("\n[Failed to start Codex: \(error.localizedDescription)]\n")
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

        Task { @MainActor in
            self.output.append("\n> \(line)\n")
        }
    }

    func send(data: Data) {
        guard let master = ptyMaster else { return }
        master.write(data)
    }

    func attachOutput(_ handler: @escaping (Data) -> Void) {
        outputHandler = handler
    }

    func detachOutput() {
        outputHandler = nil
    }

    private static func openPty() -> (FileHandle, FileHandle)? {
        var master: Int32 = 0
        var slave: Int32 = 0
        let result = openpty(&master, &slave, nil, nil, nil)
        guard result == 0 else { return nil }

        let masterHandle = FileHandle(fileDescriptor: master, closeOnDealloc: true)
        let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
        return (masterHandle, slaveHandle)
    }

}
