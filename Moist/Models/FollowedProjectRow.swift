//
//  FollowedProjectRow.swift
//  Rawdea
//

import Foundation

/// One followed Project on Home: its latest change and how much
/// is new since it was last opened.
struct FollowedProjectRow: Identifiable {

    /// Posts looked at per Project; more new ones read as "9+".
    static let postsPerProject = 10

    let project: Project
    let summary: String
    let latestAt: Date
    let newCount: Int

    var id: UUID { project.id }

    var newCountText: String {
        newCount >= Self.postsPerProject ? "9+" : "\(newCount)"
    }

    /// `posts` are the Project's latest, newest first.
    init(project: Project, posts: [Post], lastSeen: Date?) {
        self.project = project

        func isNew(_ date: Date) -> Bool {
            lastSeen.map { date > $0 } ?? true
        }

        // A stage that was never moved dates from creation.
        let movedAt = project.stageChangedAt > project.createdAt
            ? project.stageChangedAt
            : nil

        if let movedAt, movedAt > (posts.first?.createdAt ?? .distantPast) {
            summary = "Moved to \(project.stage.title)"
            latestAt = movedAt
        } else if let post = posts.first {
            summary = "\(post.kind.title): \(post.content)"
            latestAt = post.createdAt
        } else {
            summary = "Nothing shared yet"
            latestAt = project.createdAt
        }

        newCount = min(
            posts.filter { isNew($0.createdAt) }.count
                + (movedAt.map(isNew) == true ? 1 : 0),
            Self.postsPerProject
        )
    }
}
