import Foundation

enum PreviewPathResolver {
    static func resolve(rootPath: String, worktreePath: String) -> String {
        let trimmed = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return worktreePath }
        if trimmed.hasPrefix("/") { return trimmed }
        let relative = trimmed.hasPrefix("./") ? String(trimmed.dropFirst(2)) : trimmed
        return URL(fileURLWithPath: worktreePath).appendingPathComponent(relative).path
    }
}
