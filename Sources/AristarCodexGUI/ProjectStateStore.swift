import Foundation

struct ProjectState: Codable {
    var baseBranch: String?
    var selectedWorktreePath: String?
}

enum ProjectStateStore {
    private static let defaults = UserDefaults.standard
    private static let keyPrefix = "ProjectState."

    static func load(for projectKey: String) -> ProjectState? {
        guard let data = defaults.data(forKey: keyPrefix + projectKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ProjectState.self, from: data)
    }

    static func save(_ state: ProjectState, for projectKey: String) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: keyPrefix + projectKey)
        }
    }

    static func clear(for projectKey: String) {
        defaults.removeObject(forKey: keyPrefix + projectKey)
    }
}
