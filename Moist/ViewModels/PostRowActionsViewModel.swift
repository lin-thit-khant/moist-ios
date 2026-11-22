//
//  PostRowActionsViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class PostRowActionsViewModel: ObservableObject {

    @Published private(set) var isLiked = false
    @Published private(set) var isBookmarked = false

    @Published private(set) var hasLoaded = false
    @Published private(set) var isLoading = false

    @Published private(set) var isUpdatingLike = false
    @Published private(set) var isUpdatingBookmark = false

    @Published private(set) var errorMessage: String?

    private let service: PostRowActionsService

    init(
        service: PostRowActionsService =
            PostRowActionsService()
    ) {
        self.service = service
    }

    // MARK: - Load or refresh

    func load(postId: UUID) async {

        guard !isLoading,
              !isUpdatingLike,
              !isUpdatingBookmark else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let snapshot = try await service.load(
                postId: postId
            )

            try Task.checkCancellation()

            isLiked = snapshot.isLiked
            isBookmarked = snapshot.isBookmarked
            hasLoaded = true

        } catch is CancellationError {
            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            hasLoaded = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Like

    func toggleLike(postId: UUID) async {

        guard hasLoaded,
              !isLoading,
              !isUpdatingLike else {
            return
        }

        isUpdatingLike = true
        errorMessage = nil

        defer {
            isUpdatingLike = false
        }

        let newValue = !isLiked

        do {

            try await service.setLiked(
                newValue,
                postId: postId
            )

            isLiked = newValue

        } catch {

            errorMessage =
                "Couldn't update Like. \(error.localizedDescription)"
        }
    }

    // MARK: - Bookmark

    func toggleBookmark(postId: UUID) async {

        guard hasLoaded,
              !isLoading,
              !isUpdatingBookmark else {
            return
        }

        isUpdatingBookmark = true
        errorMessage = nil

        defer {
            isUpdatingBookmark = false
        }

        let newValue = !isBookmarked

        do {

            try await service.setBookmarked(
                newValue,
                postId: postId
            )

            isBookmarked = newValue

        } catch {

            errorMessage =
                "Couldn't update Bookmark. \(error.localizedDescription)"
        }
    }
}
