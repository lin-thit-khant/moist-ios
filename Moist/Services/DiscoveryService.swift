//
//  DiscoveryService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Supabase

// MARK: - Search Result Page

struct DiscoveryPage<Item> {

    let items: [Item]
    let consumedCount: Int
    let hasMore: Bool
}

// MARK: - Service

struct DiscoveryService {

    private let client: SupabaseClient
    private let postService: PostService

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
        self.postService = PostService(client: client)
    }

    // MARK: - Search People

    func searchPeople(
        term: String,
        offset: Int,
        limit: Int = 20
    ) async throws -> DiscoveryPage<Profile> {

        let page = try await fetchIDs(
            function: "rawdea_search_people",
            term: term,
            offset: offset,
            limit: limit
        )

        guard !page.ids.isEmpty else {
            return DiscoveryPage(
                items: [],
                consumedCount: 0,
                hasMore: false
            )
        }

        let profiles: [Profile] = try await client
            .from("profiles")
            .select()
            .in(
                "id",
                values: page.ids.map(\.uuidString)
            )
            .execute()
            .value

        try Task.checkCancellation()

        let byID = Dictionary(
            uniqueKeysWithValues: profiles.map {
                ($0.id, $0)
            }
        )

        let ordered = page.ids.compactMap {
            byID[$0]
        }

        return DiscoveryPage(
            items: ordered,
            consumedCount: page.ids.count,
            hasMore: page.hasMore
        )
    }

    // MARK: - Search Projects

    func searchProjects(
        term: String,
        offset: Int,
        limit: Int = 20
    ) async throws -> DiscoveryPage<Project> {

        let page = try await fetchIDs(
            function: "rawdea_search_projects",
            term: term,
            offset: offset,
            limit: limit
        )

        guard !page.ids.isEmpty else {
            return DiscoveryPage(
                items: [],
                consumedCount: 0,
                hasMore: false
            )
        }

        let projects: [Project] = try await client
            .from("projects")
            .select()
            .in(
                "id",
                values: page.ids.map(\.uuidString)
            )
            .eq("is_hidden", value: false)
            .eq("is_archived", value: false)
            .execute()
            .value

        try Task.checkCancellation()

        let byID = Dictionary(
            uniqueKeysWithValues: projects.map {
                ($0.id, $0)
            }
        )

        let ordered = page.ids.compactMap {
            byID[$0]
        }

        return DiscoveryPage(
            items: ordered,
            consumedCount: page.ids.count,
            hasMore: page.hasMore
        )
    }

    // MARK: - Search Posts

    func searchPosts(
        term: String,
        offset: Int,
        limit: Int = 20
    ) async throws -> DiscoveryPage<Post> {

        let page = try await fetchIDs(
            function: "rawdea_search_posts",
            term: term,
            offset: offset,
            limit: limit
        )

        guard !page.ids.isEmpty else {
            return DiscoveryPage(
                items: [],
                consumedCount: 0,
                hasMore: false
            )
        }

        // Reuse the existing PostService.
        // Its queries already include author
        // and Project information.

        let posts = try await postService.fetchPosts(
            postIds: page.ids
        )

        try Task.checkCancellation()

        let byID = Dictionary(
            uniqueKeysWithValues: posts.map {
                ($0.id, $0)
            }
        )

        let ordered = page.ids.compactMap {
            byID[$0]
        }
        .filter { !$0.isHidden }

        return DiscoveryPage(
            items: ordered,
            consumedCount: page.ids.count,
            hasMore: page.hasMore
        )
    }

    // MARK: - Private ID Search

    private func fetchIDs(
        function: String,
        term: String,
        offset: Int,
        limit: Int
    ) async throws -> DiscoveryIDPage {

        let safeLimit = min(max(limit, 1), 49)

        let parameters = DiscoverySearchParameters(
            searchTerm: term,
            pageSize: safeLimit + 1,
            pageOffset: max(offset, 0)
        )

        let records: [DiscoveryIDRecord] = try await client
            .rpc(
                function,
                params: parameters
            )
            .execute()
            .value

        try Task.checkCancellation()

        return DiscoveryIDPage(
            ids: Array(
                records.prefix(safeLimit).map(\.id)
            ),
            hasMore: records.count > safeLimit
        )
    }
}

// MARK: - Internal RPC Models

private struct DiscoveryIDRecord: Decodable {
    let id: UUID
}

private struct DiscoveryIDPage {
    let ids: [UUID]
    let hasMore: Bool
}

private struct DiscoverySearchParameters: Encodable {

    let searchTerm: String
    let pageSize: Int
    let pageOffset: Int

    enum CodingKeys: String, CodingKey {
        case searchTerm = "search_term"
        case pageSize = "page_size"
        case pageOffset = "page_offset"
    }
}
