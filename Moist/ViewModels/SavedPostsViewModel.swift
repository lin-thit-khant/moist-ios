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
        service: BookmarkService =
            BookmarkService()
    ) {

        self.service = service
    }

    var isBusy: Bool {

        isLoading ||
        removingPostId != nil
    }

    // MARK: - Revalidate visibility

    func reloadVisiblePosts() async {

        guard !isBusy else {
            return
        }

        // Never keep previously loaded content
        // during a fresh visibility check.

        posts = []
        hasBookmarks = false
        hasLoaded = false

        await fetchSnapshot()
    }

    // MARK: - Refresh saved posts

    func loadPosts() async {

        guard !isBusy else {
            return
        }

        await fetchSnapshot()
    }

    // MARK: - Shared snapshot loading

    private func fetchSnapshot() async {

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

    // MARK: - Unsave

    func removePost(
        postId: UUID
    ) async {

        guard !isBusy,
              posts.contains(
                where: { $0.id == postId }
              ) else {

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

        } catch {

            // The removal failed. Do not hide
            // the original saved post.

            actionErrorMessage =
                error.localizedDescription

            return
        }

        // The database confirmed removal.
        // Update the visible list immediately.

        posts.removeAll {
            $0.id == postId
        }

        // Reconcile the remaining bookmarks,
        // including any newly available posts.

        await fetchSnapshot()
    }

    func clearActionError() {

        actionErrorMessage = nil
    }
}
