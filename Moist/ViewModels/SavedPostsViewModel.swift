//
//  SavedPostsViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class SavedPostsViewModel: ObservableObject {

    @Published private(set) var posts: [Post] = []

    @Published private(set) var hasBookmarks = false
    @Published private(set) var hasLoaded = false

    @Published private(set) var isLoading = false
    @Published private(set) var removingPostId: UUID?

    @Published private(set) var errorMessage: String?
    @Published private(set) var actionErrorMessage: String?

    private let service: BookmarkService

    init(
        service: BookmarkService = BookmarkService()
    ) {
        self.service = service
    }

    // MARK: - Load Saved Posts

    func loadPosts() async {

        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let snapshot = try await service
                .fetchSavedPosts()

            try Task.checkCancellation()

            posts = snapshot.posts
            hasBookmarks = snapshot.hasBookmarks
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

    // MARK: - Remove From Saved Posts

    func removePost(postId: UUID) async {

        guard !isLoading,
              removingPostId == nil else {
            return
        }

        removingPostId = postId
        actionErrorMessage = nil

        defer {
            removingPostId = nil
        }

        do {

            try await service.removeBookmark(
                postId: postId
            )

            // Immediately remove the row.

            posts.removeAll {
                $0.id == postId
            }

            // Refresh to keep the collection
            // and its empty state consistent.

            await loadPosts()

        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    func clearActionError() {
        actionErrorMessage = nil
    }
}
