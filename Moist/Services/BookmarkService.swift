//
//  BookmarkService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Supabase

struct SavedPostsSnapshot {

    let posts: [Post]
    let hasBookmarks: Bool
}

struct BookmarkService {

    private let client: SupabaseClient
    private let postService: PostService

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
        self.postService = PostService(client: client)
    }

    // MARK: - Bookmark Status

    func isBookmarked(
        postId: UUID
    ) async throws -> Bool {

        let user = try await client.auth.session.user

        let records: [PostBookmark] = try await client
            .from("post_bookmarks")
            .select("post_id")
            .eq("user_id", value: user.id)
            .eq("post_id", value: postId)
            .limit(1)
            .execute()
            .value

        return !records.isEmpty
    }

    // MARK: - Save Post

    func savePost(
        postId: UUID
    ) async throws {

        let user = try await client.auth.session.user

        let payload = NewPostBookmark(
            userId: user.id,
            postId: postId
        )

        try await client
            .from("post_bookmarks")
            .insert(payload)
            .select("post_id")
            .single()
            .execute()
    }

    // MARK: - Remove Bookmark

    func removeBookmark(
        postId: UUID
    ) async throws {

        let user = try await client.auth.session.user

        try await client
            .from("post_bookmarks")
            .delete()
            .eq("user_id", value: user.id)
            .eq("post_id", value: postId)
            .select("post_id")
            .single()
            .execute()
    }

    // MARK: - Load Saved Posts

    func fetchSavedPosts() async throws -> SavedPostsSnapshot {

        let user = try await client.auth.session.user

        // 1. Read the latest 100 bookmark records.

        let bookmarks: [PostBookmark] = try await client
            .from("post_bookmarks")
            .select("post_id")
            .eq("user_id", value: user.id)
            .order("created_at", ascending: false)
            .order("post_id", ascending: false)
            .limit(100)
            .execute()
            .value

        try Task.checkCancellation()

        guard !bookmarks.isEmpty else {
            return SavedPostsSnapshot(
                posts: [],
                hasBookmarks: false
            )
        }

        // 2. Fetch corresponding posts in batches.
        // RLS filters out posts the viewer cannot read.

        let batchSize = 40

        var postsById: [UUID: Post] = [:]

        for startIndex in stride(
            from: 0,
            to: bookmarks.count,
            by: batchSize
        ) {

            try Task.checkCancellation()

            let endIndex = min(
                startIndex + batchSize,
                bookmarks.count
            )

            let postIds = bookmarks[startIndex..<endIndex]
                .map(\.postId)

            let fetchedPosts = try await postService
                .fetchPosts(postIds: postIds)

            for post in fetchedPosts {
                postsById[post.id] = post
            }
        }

        try Task.checkCancellation()

        // 3. Restore bookmark order.
        //
        // Database results from an IN query
        // may arrive in a different order.
        //
        // Here we preserve newest-saved-first,
        // not newest-published-first.

        let orderedPosts = bookmarks.compactMap {
            bookmark in

            postsById[bookmark.postId]
        }

        return SavedPostsSnapshot(
            posts: orderedPosts,
            hasBookmarks: true
        )
    }
}

// MARK: - Database Payload

private struct NewPostBookmark: Encodable {

    let userId: UUID
    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case postId = "post_id"
    }
}
