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

/// A Project on Explore with its newest post.
struct ActiveProject: Identifiable {
    let project: Project
    let latest: Post

    var id: UUID { project.id }
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

    // MARK: - Explore

    /// Posts from visible Projects, newest first. Posts policies
    /// already leave out blocked and removed content. The inner
    /// join lets the query filter by the Project.
    private static let visiblePostSelection = PostService.selection
        .replacingOccurrences(
            of: "posts_project_owner_fk(",
            with: "posts_project_owner_fk!inner("
        )

    // shortcut: looks at the newest 100 posts. Replace with a
    // database function when one busy Project can fill them.
    func fetchActiveProjects(
        stage: ProjectStage?,
        limit: Int = 10
    ) async throws -> [ActiveProject] {

        var query = client
            .from("posts")
            .select("""
                *,
                project: projects!posts_project_owner_fk!inner(id, name)
                """)
            .eq("is_hidden", value: false)
            .eq("project.is_hidden", value: false)
            .eq("project.is_archived", value: false)
            .eq("project.is_default", value: false)

        if let stage {
            query = query.eq("project.stage", value: stage.rawValue)
        }

        let posts: [Post] = try await query
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        var seen = Set<UUID>()
        let latest = posts.filter { post in
            post.projectId.map { seen.insert($0).inserted } ?? false
        }
        .prefix(limit)

        guard !latest.isEmpty else { return [] }

        let projects: [Project] = try await client
            .from("projects")
            .select()
            .in("id", values: latest.compactMap { $0.projectId?.uuidString })
            .execute()
            .value

        let byID = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })

        return latest.compactMap { post in
            post.projectId
                .flatMap { byID[$0] }
                .map { ActiveProject(project: $0, latest: post) }
        }
    }

    func fetchOpenQuestions(limit: Int = 10) async throws -> [Post] {

        try await client
            .from("posts")
            .select(Self.visiblePostSelection)
            .eq("kind", value: PostKind.question.rawValue)
            .is("best_reply_id", value: nil)
            .eq("is_hidden", value: false)
            .eq("project.is_hidden", value: false)
            .eq("project.is_archived", value: false)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
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
