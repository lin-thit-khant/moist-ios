//
//  FollowingFeedService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import Foundation

struct FollowingFeedService {

    private let followingService: FollowingService
    private let pagingService: FeedPagingService
    private let postService: PostService

    init(
        followingService: FollowingService =
            FollowingService(),
        pagingService: FeedPagingService =
            FeedPagingService(),
        postService: PostService = PostService()
    ) {
        self.followingService = followingService
        self.pagingService = pagingService
        self.postService = postService
    }

    // MARK: - Followed Stage Changes

    /// Changes in followed Projects or by followed people.
    func fetchStageRows() async throws -> [HomeStageRow] {

        let projects = Set(try await followingService
            .fetchFollowingProjects().map(\.id))
        let people = Set(try await followingService
            .fetchFollowingPeople().map(\.id))

        return try await ProjectService()
            .fetchRecentStageRows()
            .filter {
                projects.contains($0.project.id) ||
                people.contains($0.project.userId)
            }
    }

    // MARK: - Followed Projects

    // shortcut: one request per followed Project. Replace with one
    // database function when people follow dozens of Projects.
    func fetchProjectRows() async throws -> [FollowedProjectRow] {

        let projects = try await followingService
            .fetchFollowingProjects()
        let lastSeen = try await followingService
            .fetchProjectLastSeen()

        var rows: [FollowedProjectRow] = []

        for project in projects {
            try Task.checkCancellation()

            let posts = try await postService.fetchLatestPosts(
                projectId: project.id,
                limit: FollowedProjectRow.postsPerProject
            )

            rows.append(FollowedProjectRow(
                project: project,
                posts: posts,
                lastSeen: lastSeen[project.id]
            ))
        }

        return rows.sorted { $0.latestAt > $1.latestAt }
    }

    // MARK: - Follow Source Check

    func hasFollowedSources() async throws -> Bool {

        let people = try await followingService
            .fetchFollowingPeople()

        try Task.checkCancellation()

        let projects = try await followingService
            .fetchFollowingProjects()

        try Task.checkCancellation()

        return !people.isEmpty || !projects.isEmpty
    }

    // MARK: - Following Posts Page

    func fetchPage(
        before cursor: RawdeaPageCursor? = nil
    ) async throws -> RawdeaPage<Post> {

        try await pagingService.fetchFollowingPosts(
            before: cursor
        )
    }
}

