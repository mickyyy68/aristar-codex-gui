import Foundation

enum RecentProjectStore {
    private static let defaults = UserDefaults.standard
    private static let key = "RecentProjectPath"

    static func save(url: URL) {
        defaults.set(url.path, forKey: key)
    }

    static func load() -> URL? {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}
