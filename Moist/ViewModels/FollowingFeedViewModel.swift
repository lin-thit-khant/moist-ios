//
//  FollowingFeedViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class FollowingFeedViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var posts: [Post] = []

    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false

    @Published private(set) var hasLoaded = false
    @Published private(set) var hasMore = false

    @Published private(set) var hasFollowedSources = false

    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?

    // MARK: - Dependencies

    private let followingFeedService: FollowingFeedService

    private var nextPageCursor: RawdeaPageCursor?

    init(
        followingFeedService: FollowingFeedService =
            FollowingFeedService()
    ) {
        self.followingFeedService = followingFeedService
    }

    
    // MARK: - Revalidate Following Feed

    func reloadVisiblePosts() async {

        guard !isLoading && !isLoadingMore else {
            return
        }

        posts = []

        hasLoaded = false
        hasFollowedSources = false
        hasMore = false

        nextPageCursor = nil

        await loadPosts()
    }

    
    // MARK: - Load First Page

    func loadPosts() async {

        guard !isLoading && !isLoadingMore else {
            return
        }

        isLoading = true
        errorMessage = nil
        paginationErrorMessage = nil

        defer {
            isLoading = false
        }

        do {

            // Check whether the user follows
            // anyone or any public Projects.

            let hasSources = try await followingFeedService
                .hasFollowedSources()

            try Task.checkCancellation()

            // No followed sources means
            // no Following feed posts.

            guard hasSources else {

                posts = []
                hasFollowedSources = false
                hasMore = false
                nextPageCursor = nil
                hasLoaded = true

                return
            }

            // Load the first page.

            let page = try await followingFeedService
                .fetchPage(before: nil)

            try Task.checkCancellation()

            posts = page.items

            hasFollowedSources = true

            nextPageCursor = page.nextCursor
            hasMore = page.hasMore

            hasLoaded = true

        } catch is CancellationError {
            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load More

    func loadMorePosts() async {

        guard hasMore,
              !isLoading,
              !isLoadingMore,
              let cursor = nextPageCursor else {
            return
        }

        isLoadingMore = true
        paginationErrorMessage = nil

        defer {
            isLoadingMore = false
        }

        do {

            let page = try await followingFeedService
                .fetchPage(before: cursor)

            try Task.checkCancellation()

            let existingIDs = Set(
                posts.map(\.id)
            )

            posts.append(
                contentsOf: page.items.filter {
                    !existingIDs.contains($0.id)
                }
            )

            nextPageCursor = page.nextCursor
            hasMore = page.hasMore

        } catch is CancellationError {
            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            paginationErrorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Refresh

    func refreshPosts() async {
        await loadPosts()
    }
}

