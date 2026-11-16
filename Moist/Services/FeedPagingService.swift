//
//  FeedPagingService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Supabase

// MARK: - Shared Cursor

struct RawdeaPageCursor: Equatable {

    let createdAt: String
    let id: UUID
}

// MARK: - Shared Page

struct RawdeaPage<Item> {

    let items: [Item]
    let nextCursor: RawdeaPageCursor?
    let hasMore: Bool
}

// MARK: - RPC Record

struct RawdeaPageRecord: Decodable {

    let id: UUID
    let createdAtCursor: String

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtCursor = "created_at_cursor"
    }

    var cursor: RawdeaPageCursor {
        RawdeaPageCursor(
            createdAt: createdAtCursor,
            id: id
        )
    }
}

// MARK: - Feed Paging Service

struct FeedPagingService {

    private let client: SupabaseClient
    private let postService: PostService

    private let pageSize = 20

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
        self.postService = PostService(client: client)
    }

    // MARK: - All Posts

    func fetchAllPosts(
        before cursor: RawdeaPageCursor? = nil
    ) async throws -> RawdeaPage<Post> {

        try await fetchPage(
            function: "rawdea_page_all_posts",
            before: cursor
        )
    }

    // MARK: - Following Posts

    func fetchFollowingPosts(
        before cursor: RawdeaPageCursor? = nil
    ) async throws -> RawdeaPage<Post> {

        try await fetchPage(
            function: "rawdea_page_following_posts",
            before: cursor
        )
    }

    // MARK: - Private Fetch

    private func fetchPage(
        function: String,
        before cursor: RawdeaPageCursor?
    ) async throws -> RawdeaPage<Post> {

        let parameters = FeedPageParameters(
            beforeCreatedAt: cursor?.createdAt,
            beforeId: cursor?.id,
            batchSize: pageSize + 1
        )

        let records: [RawdeaPageRecord] = try await client
            .rpc(
                function,
                params: parameters
            )
            .execute()
            .value

        try Task.checkCancellation()

        // Request 21 rows, but display at most 20.

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

        // Hydrate posts using the existing
        // PostService and its standard selection.

        let fetchedPosts = try await postService.fetchPosts(
            postIds: selectedRecords.map(\.id)
        )

        try Task.checkCancellation()

        let postsByID = Dictionary(
            uniqueKeysWithValues: fetchedPosts.map {
                ($0.id, $0)
            }
        )

        // Restore the exact cursor-query order.

        let orderedPosts = selectedRecords.compactMap {
            postsByID[$0.id]
        }

        return RawdeaPage(
            items: orderedPosts,
            nextCursor: selectedRecords.last?.cursor,
            hasMore: records.count > pageSize
        )
    }
}

// MARK: - RPC Parameters

private struct FeedPageParameters: Encodable {

    let beforeCreatedAt: String?
    let beforeId: UUID?
    let batchSize: Int

    enum CodingKeys: String, CodingKey {
        case beforeCreatedAt = "before_created_at"
        case beforeId = "before_id"
        case batchSize = "batch_size"
    }
}
