import Foundation

enum WorkingSetStore {
    private static let defaults = UserDefaults.standard
    private static let key = "WorkingWorktrees"

    static func load() -> [WorkingSetItem] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([WorkingSetItem].self, from: data) {
            return list
        }
        return []
    }

    static func save(_ items: [WorkingSetItem]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}
