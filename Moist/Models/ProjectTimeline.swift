//
//  ProjectTimeline.swift
//  Rawdea
//

import Foundation

/// A Project's posts and stage changes, newest first, grouped
/// by the stage the Project was in at the time.
enum ProjectTimeline {

    enum Item: Identifiable {
        case post(Post)
        case stageChange(ProjectStageEvent)

        var id: UUID {
            switch self {
            case .post(let post): post.id
            case .stageChange(let event): event.id
            }
        }
    }

    struct Group: Identifiable {
        let stage: ProjectStage
        var items: [Item]
        var id: UUID { items.first?.id ?? UUID() }

        /// When this stage began, if a recorded change began it.
        var startedAt: Date? {
            if case .stageChange(let event) = items.last {
                return event.createdAt
            }
            return nil
        }
    }

    static func groups(
        posts: [Post],
        events: [ProjectStageEvent],
        currentStage: ProjectStage
    ) -> [Group] {

        // The post that announced a change belongs to the new
        // stage, although it was published just before it.
        var announced: [UUID: Date] = [:]
        for event in events {
            if let postId = event.postId {
                announced[postId] = event.createdAt
            }
        }

        // Rank 1 sits above rank 0 at the same moment.
        var entries: [(date: Date, rank: Int, item: Item)] = posts.map { post in
            if let date = announced[post.id] {
                return (date, 1, .post(post))
            }
            return (post.createdAt, 1, .post(post))
        }
        entries += events.map { ($0.createdAt, 0, .stageChange($0)) }
        entries.sort { ($0.date, $0.rank) > ($1.date, $1.rank) }

        var groups: [Group] = []
        var stage = currentStage
        var items: [Item] = []

        for entry in entries {
            items.append(entry.item)

            // A change is where its stage began.
            if case .stageChange(let event) = entry.item {
                groups.append(Group(stage: stage, items: items))
                items = []
                stage = event.fromStage
            }
        }

        if !items.isEmpty {
            groups.append(Group(stage: stage, items: items))
        }

        return groups
    }
}
