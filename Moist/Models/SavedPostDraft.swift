import Foundation

struct SavedPostDraft: Codable, Equatable {
    let content: String
    let projectId: UUID?
    let kind: PostKind

    static func load(for userId: UUID, defaults: UserDefaults = .standard) -> Self? {
        guard let data = defaults.data(forKey: key(for: userId)) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func save(_ draft: Self?, for userId: UUID, defaults: UserDefaults = .standard) {
        let key = key(for: userId)
        if let draft, let data = try? JSONEncoder().encode(draft) {
            defaults.set(data, forKey: key)
        } else if draft == nil {
            defaults.removeObject(forKey: key)
        }
    }

    private static func key(for userId: UUID) -> String {
        "rawdea.compose.draft.\(userId.uuidString)"
    }
}
