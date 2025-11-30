import Foundation

struct PreviewServiceConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var command: String = ""
    var rootPath: String = ""
    var envText: String = ""
    var enabled: Bool = true
}

struct WorktreeMetadata: Codable {
    let originalBranch: String
    let agentBranch: String
    let createdAt: Date
    var previewServices: [PreviewServiceConfig]

    init(originalBranch: String, agentBranch: String, createdAt: Date, previewServices: [PreviewServiceConfig] = []) {
        self.originalBranch = originalBranch
        self.agentBranch = agentBranch
        self.createdAt = createdAt
        self.previewServices = previewServices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        originalBranch = try container.decode(String.self, forKey: .originalBranch)
        agentBranch = try container.decode(String.self, forKey: .agentBranch)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        previewServices = try container.decodeIfPresent([PreviewServiceConfig].self, forKey: .previewServices) ?? []
    }
}

struct ManagedWorktree: Identifiable, Equatable {
    let path: URL
    let originalBranch: String
    let agentBranch: String
    let createdAt: Date?
    var previewServices: [PreviewServiceConfig]

    init(path: URL, originalBranch: String, agentBranch: String, createdAt: Date?, previewServices: [PreviewServiceConfig] = []) {
        self.path = path
        self.originalBranch = originalBranch
        self.agentBranch = agentBranch
        self.createdAt = createdAt
        self.previewServices = previewServices
    }

    var id: String { path.path }
    var displayName: String { path.lastPathComponent }
}
