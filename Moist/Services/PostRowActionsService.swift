//
//  PostRowActionsService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//


import Foundation
import Supabase

struct PostRowActionsSnapshot {
    let isLiked: Bool
    let isBookmarked: Bool
}

struct PostRowActionsService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Load viewer-specific state

    func load(
        postId: UUID
    ) async throws -> PostRowActionsSnapshot {

        let viewer = try await client.auth.session.user

        let likes: [PostRowLikePresence] = try await client
            .from("post_likes")
            .select("post_id")
            .eq("post_id", value: postId)
            .eq("user_id", value: viewer.id)
            .limit(1)
            .execute()
            .value

        try Task.checkCancellation()

        let saved = try await BookmarkService(
            client: client
        ).isBookmarked(postId: postId)

        try Task.checkCancellation()

        return PostRowActionsSnapshot(
            isLiked: !likes.isEmpty,
            isBookmarked: saved
        )
    }

    // MARK: - Like / Unlike

    func setLiked(
        _ liked: Bool,
        postId: UUID
    ) async throws {

        let engagement = PostEngagementService(
            client: client
        )

        if liked {
            try await engagement.like(postId: postId)
        } else {
            try await engagement.unlike(postId: postId)
        }
    }

    // MARK: - Save / Unsave

    func setBookmarked(
        _ bookmarked: Bool,
        postId: UUID
    ) async throws {

        let bookmarks = BookmarkService(
            client: client
        )

        if bookmarked {
            try await bookmarks.savePost(
                postId: postId
            )
        } else {
            try await bookmarks.removeBookmark(
                postId: postId
            )
        }
    }
}

private struct PostRowLikePresence: Decodable {

    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
    }
}
