//
//  RawdeaFeedEntry.swift
//  Rawdea
//

import Foundation

/// One row of a Home feed. Posts next to each other from the same
/// Project read as a thread, and a long thread is cut short.
enum RawdeaFeedEntry: Identifiable {

    case post(Post, showsProject: Bool, continuesThread: Bool)
    case more(project: PostProject, count: Int, after: UUID)

    static let visiblePostsPerThread = 2

    var id: String {
        switch self {
        case .post(let post, _, _):
            return post.id.uuidString
        case .more(_, _, let postID):
            return "more-\(postID.uuidString)"
        }
    }

    /// Whether a divider belongs under this row.
    var endsGroup: Bool {
        switch self {
        case .post(_, _, let continuesThread):
            return !continuesThread
        case .more:
            return true
        }
    }

    /// Keeps the feed's order. Only loaded posts are counted.
    static func entries(for posts: [Post]) -> [RawdeaFeedEntry] {
        var entries: [RawdeaFeedEntry] = []
        var start = 0

        while start < posts.count {
            var end = start + 1
            if let projectID = posts[start].project?.id {
                while end < posts.count, posts[end].project?.id == projectID {
                    end += 1
                }
            }

            let run = posts[start..<end]
            let visible = Array(run.prefix(visiblePostsPerThread))
            let hiddenCount = run.count - visible.count

            for (index, post) in visible.enumerated() {
                entries.append(.post(
                    post,
                    showsProject: index == 0,
                    continuesThread: index < visible.count - 1 || hiddenCount > 0
                ))
            }

            if hiddenCount > 0,
               let project = posts[start].project,
               let last = visible.last {
                entries.append(.more(project: project, count: hiddenCount, after: last.id))
            }

            start = end
        }

        return entries
    }
}
