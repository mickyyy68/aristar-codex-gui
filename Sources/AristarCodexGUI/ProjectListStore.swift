import Foundation

enum ProjectListStore {
    private static let defaults = UserDefaults.standard
    private static let recentsKey = "RecentProjectPaths"
    private static let favoritesKey = "FavoriteProjectPaths"

    static func saveRecents(_ projects: [ProjectRef]) {
        defaults.set(projects.map { $0.path }, forKey: recentsKey)
    }

    static func saveFavorites(_ projects: [ProjectRef]) {
        defaults.set(projects.map { $0.path }, forKey: favoritesKey)
    }

    static func loadRecents() -> [ProjectRef] {
        guard let list = defaults.stringArray(forKey: recentsKey) else { return [] }
        return list.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ProjectRef(url: url)
        }
    }

    static func loadFavorites() -> [ProjectRef] {
        guard let list = defaults.stringArray(forKey: favoritesKey) else { return [] }
        return list.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return ProjectRef(url: url)
        }
    }
}
