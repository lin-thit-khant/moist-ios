//
//  PostEngagementService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Supabase

struct PostEngagementSnapshot {

    let post: Post
    let viewerId: UUID
    let likeCount: Int
    let isLiked: Bool
    
    let comments: [PostComment]
    let commentsCursor: RawdeaPageCursor?
    let hasMoreComments: Bool
}

enum PostEngagementError: LocalizedError {

    case unavailable
    case emptyComment
    case commentTooLong

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "This post is unavailable or no longer visible."
        case .emptyComment:
            return "Comment cannot be empty."
        case .commentTooLong:
            return "Comment cannot exceed 500 characters."
        }
    }
}

struct PostEngagementService {

    private let client: SupabaseClient
    private let postService: PostService

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
        self.postService = PostService(client: client)
    }

    // MARK: - Comment Selection

    private var commentSelection: String {
        """
        id,
        post_id,
        user_id,
        content,
        created_at,
        author:profiles!post_comments_user_id_fkey(
            id,
            display_name,
            username
        )
        """
    }

    // MARK: - Load Discussion

    func fetchDiscussion(
        postId: UUID
    ) async throws -> PostEngagementSnapshot {

        let user = try await client.auth.session.user

        guard let post = try await postService.fetchPost(
            postId: postId
        ) else {
            throw PostEngagementError.unavailable
        }

        try Task.checkCancellation()

        let likeResponse = try await client
            .from("post_likes")
            .select("*", head: true, count: .exact)
            .eq("post_id", value: postId)
            .execute()

        let likedRows: [PostLikePresence] = try await client
            .from("post_likes")
            .select("post_id")
            .eq("post_id", value: postId)
            .eq("user_id", value: user.id)
            .limit(1)
            .execute()
            .value

        let commentsPage = try await fetchCommentsPage(
            postId: postId,
            before: nil
        )

        try Task.checkCancellation()

        return PostEngagementSnapshot(
            post: post,
            viewerId: user.id,
            likeCount: likeResponse.count ?? 0,
            isLiked: !likedRows.isEmpty,

            comments: commentsPage.items,
            commentsCursor: commentsPage.nextCursor,
            hasMoreComments: commentsPage.hasMore
        )
    }
    
    
    // MARK: - Paginated Comments

    func fetchCommentsPage(
        postId: UUID,
        before cursor: RawdeaPageCursor?
    ) async throws -> RawdeaPage<PostComment> {

        let pageSize = 20

        let parameters = CommentPageParameters(
            targetPostId: postId,
            beforeCreatedAt: cursor?.createdAt,
            beforeId: cursor?.id,
            batchSize: pageSize + 1
        )

        // 1. Fetch ordered comment IDs and
        // their exact pagination cursors.

        let records: [RawdeaPageRecord] = try await client
            .rpc(
                "rawdea_page_post_comments",
                params: parameters
            )
            .execute()
            .value

        try Task.checkCancellation()

        let selectedRecords = Array(
            records.prefix(pageSize)
        )

        guard !selectedRecords.isEmpty else {
            return RawdeaPage(
                items: [],
                nextCursor: nil,
                hasMore: false
            )
        }

        // 2. Fetch complete comments including
        // author information.

        let comments: [PostComment] = try await client
            .from("post_comments")
            .select(commentSelection)
            .eq("post_id", value: postId)
            .in(
                "id",
                values: selectedRecords.map {
                    $0.id.uuidString
                }
            )
            .execute()
            .value

        try Task.checkCancellation()

        // 3. Restore the database's sort order.

        let commentsByID = Dictionary(
            uniqueKeysWithValues: comments.map {
                ($0.id, $0)
            }
        )

        let orderedComments = selectedRecords.compactMap {
            commentsByID[$0.id]
        }

        return RawdeaPage(
            items: orderedComments,
            nextCursor: selectedRecords.last?.cursor,
            hasMore: records.count > pageSize
        )
    }


    // MARK: - Likes

    func like(postId: UUID) async throws {

        let user = try await client.auth.session.user

        let payload = NewPostLike(
            postId: postId,
            userId: user.id
        )

        try await client
            .from("post_likes")
            .insert(payload)
            .select("post_id")
            .single()
            .execute()
    }

    func unlike(postId: UUID) async throws {

        let user = try await client.auth.session.user

        try await client
            .from("post_likes")
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: user.id)
            .select("post_id")
            .single()
            .execute()
    }

    // MARK: - Comments

    func addComment(
        postId: UUID,
        content: String
    ) async throws -> PostComment {

        let user = try await client.auth.session.user

        let cleaned = try validatedContent(content)

        let payload = NewPostComment(
            postId: postId,
            userId: user.id,
            content: cleaned
        )

        return try await client
            .from("post_comments")
            .insert(payload)
            .select(commentSelection)
            .single()
            .execute()
            .value
    }

    func updateComment(
        commentId: UUID,
        content: String
    ) async throws -> PostComment {

        let user = try await client.auth.session.user

        let cleaned = try validatedContent(content)

        return try await client
            .from("post_comments")
            .update(["content": cleaned])
            .eq("id", value: commentId)
            .eq("user_id", value: user.id)
            .select(commentSelection)
            .single()
            .execute()
            .value
    }

    func deleteComment(
        commentId: UUID
    ) async throws {

        let user = try await client.auth.session.user

        try await client
            .from("post_comments")
            .delete()
            .eq("id", value: commentId)
            .eq("user_id", value: user.id)
            .select("id")
            .single()
            .execute()
    }

    // MARK: - Validation

    private func validatedContent(
        _ content: String
    ) throws -> String {

        let cleaned = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleaned.isEmpty else {

            throw PostEngagementError.emptyComment
        }

        guard RawdeaTextLength.count(cleaned) <= 500 else {

            throw PostEngagementError.commentTooLong
        }

        return cleaned
    }
    
    
    // MARK: - Comment Pagination Parameters

    private struct CommentPageParameters: Encodable {

        let targetPostId: UUID
        let beforeCreatedAt: String?
        let beforeId: UUID?
        let batchSize: Int

        enum CodingKeys: String, CodingKey {
            case targetPostId = "target_post_id"
            case beforeCreatedAt = "before_created_at"
            case beforeId = "before_id"
            case batchSize = "batch_size"
        }
    }

}

// MARK: - Request Payloads

private struct NewPostLike: Encodable {

    let postId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

private struct NewPostComment: Encodable {

    let postId: UUID
    let userId: UUID
    let content: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case content
    }
}

// MARK: - Response Payloads

private struct PostLikePresence: Decodable {

    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
    }
}
