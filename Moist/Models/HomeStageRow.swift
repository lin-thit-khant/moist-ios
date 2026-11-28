//
//  HomeStageRow.swift
//  Rawdea
//

import Foundation

/// A Project's stage change as it appears in a Home feed.
struct HomeStageRow: Identifiable, Decodable {

    struct Owner: Decodable {
        let username: String
    }

    struct Source: Decodable {
        let id: UUID
        let name: String
        let userId: UUID
        let owner: Owner?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case userId = "user_id"
            case owner
        }
    }

    let id: UUID
    let toStage: ProjectStage
    let createdAt: Date
    let project: Source
    var cycle: Int? = nil
    var startsCycle: Bool? = nil
    var cycleName: String? = nil

    var marker: String {
        startsCycle == true
            ? "Started \(ProjectCycle.title(cycle ?? 1, name: cycleName))"
            : "Moved to \(toStage.title)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case toStage = "to_stage"
        case createdAt = "created_at"
        case project
        case cycle
        case startsCycle = "starts_cycle"
        case cycleName = "cycle_name"
    }
}

/// Posts and stage changes in one newest-first list.
enum HomeFeedItem: Identifiable {
    case post(Post)
    case stage(HomeStageRow)

    var id: UUID {
        switch self {
        case .post(let post): post.id
        case .stage(let row): row.id
        }
    }

    var date: Date {
        switch self {
        case .post(let post): post.createdAt
        case .stage(let row): row.createdAt
        }
    }

    /// Changes older than the last loaded post wait for its page,
    /// so nothing appears out of order.
    static func merge(
        posts: [Post],
        stages: [HomeStageRow],
        hasMore: Bool
    ) -> [HomeFeedItem] {

        let oldest = posts.map(\.createdAt).min()
        let visible = stages.filter { row in
            guard hasMore, let oldest else { return true }
            return row.createdAt >= oldest
        }

        // Posts keep the order the server gave them.
        var items = posts.map(HomeFeedItem.post)
        for row in visible.sorted(by: { $0.createdAt > $1.createdAt }) {
            let index = items.firstIndex { $0.date < row.createdAt } ?? items.endIndex
            items.insert(.stage(row), at: index)
        }
        return items
    }
}
