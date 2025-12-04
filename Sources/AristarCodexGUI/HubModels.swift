import Foundation

/// Represents a reference to a project folder
struct ProjectRef: Identifiable, Equatable, Codable {
    let id: String
    let path: String
    let name: String

    init(url: URL) {
        self.path = url.path
        self.name = url.lastPathComponent
        self.id = url.path
    }

    var url: URL { URL(fileURLWithPath: path) }
}
