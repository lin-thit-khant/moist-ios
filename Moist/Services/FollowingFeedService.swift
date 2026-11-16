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

    init(
        followingService: FollowingService =
            FollowingService(),
        pagingService: FeedPagingService =
            FeedPagingService()
    ) {
        self.followingService = followingService
        self.pagingService = pagingService
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

