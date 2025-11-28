import Foundation
import Combine

@MainActor
final class CodexAuthManager: ObservableObject {
    enum Status {
        case unknown
        case checking
        case loggedOut
        case loggedIn
        case error(String)
    }

    enum AuthError: Error {
        case message(String)

        var localizedDescription: String {
            switch self {
            case .message(let msg):
                return msg
            }
        }
    }

    @Published var status: Status = .unknown
    let codexPath: String

    init(codexPath: String? = nil) {
        self.codexPath = CodexAuthManager.resolveCodexPath(preferred: codexPath)
    }

    func checkStatus() {
        status = .checking

        Task.detached { [codexPath] in
            let result = Self.runCodex(codexPath, args: ["login", "status"])
            await MainActor.run {
                switch result {
                case .success(let exitCode) where exitCode == 0:
                    self.status = .loggedIn
                case .success:
                    self.status = .loggedOut
                case .failure(let error):
                    self.status = .error(error.localizedDescription)
                }
            }
        }
    }

    func loginViaChatGPT() {
        status = .checking

        Task.detached { [codexPath] in
            let result = Self.runCodex(codexPath, args: ["login"])
            await MainActor.run {
                switch result {
                case .success(let exitCode) where exitCode == 0:
                    self.status = .loggedIn
                case .success(let exitCode):
                    self.status = .error("codex login failed (exit code \(exitCode))")
                case .failure(let error):
                    self.status = .error(error.localizedDescription)
                }
            }
        }
    }

    nonisolated private static func runCodex(_ path: String, args: [String]) -> Result<Int32, AuthError> {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return .failure(.message("codex not found at \(path)"))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return .failure(.message("Failed to launch codex: \(error.localizedDescription)"))
        }

        process.waitUntilExit()
        return .success(process.terminationStatus)
    }

    nonisolated private static func resolveCodexPath(preferred: String?) -> String {
        var candidates: [String] = []
        if let preferred, !preferred.isEmpty {
            candidates.append(preferred)
        }
        candidates.append(contentsOf: [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "/usr/bin/codex"
        ])

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathEnv.split(separator: ":").map(String.init)
            for dir in paths {
                candidates.append("\(dir)/codex")
            }
        }

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        // Fallback to the first preferred or common path; this will surface a clear error if missing.
        return candidates.first ?? "/usr/local/bin/codex"
    }
}
