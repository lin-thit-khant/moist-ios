//
//  PostBookmarkViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class PostBookmarkViewModel: ObservableObject {

    @Published private(set) var isBookmarked = false

    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var hasLoaded = false

    @Published private(set) var errorMessage: String?

    private let service: BookmarkService

    init(
        service: BookmarkService = BookmarkService()
    ) {
        self.service = service
    }

    // MARK: - Load Status

    func load(postId: UUID) async {

        guard !isLoading && !isUpdating else {
            return
        }

        isLoading = true
        hasLoaded = false
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let saved = try await service.isBookmarked(
                postId: postId
            )

            try Task.checkCancellation()

            isBookmarked = saved
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

    // MARK: - Save / Unsave

    func toggleBookmark(postId: UUID) async {

        guard hasLoaded,
              !isLoading,
              !isUpdating else {
            return
        }

        isUpdating = true
        errorMessage = nil

        defer {
            isUpdating = false
        }

        do {

            if isBookmarked {

                try await service.removeBookmark(
                    postId: postId
                )

                isBookmarked = false

            } else {

                try await service.savePost(
                    postId: postId
                )

                isBookmarked = true
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
