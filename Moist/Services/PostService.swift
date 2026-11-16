//
//  PostService.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//

import Foundation
import Supabase

struct PostService {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }
    
    func createPost(
        content: String,
        projectId: UUID? = nil
    ) async throws -> Post {
        
        let user = try await client.auth.session.user
        
        let newPost = NewPost(
            userId: user.id,
            content: content.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            projectId: projectId
        )
        
        return try await client
            .from("posts")
            .insert(newPost)
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .single()
            .execute()
            .value
    }
    
    func fetchPosts() async throws -> [Post] {
        
        return try await client
            .from("posts")
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func fetchPosts(userId: UUID) async throws -> [Post] {
        
        return try await client
            .from("posts")
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func deletePost(postId: UUID) async throws {
        
        let user = try await client.auth.session.user
        
        try await client
            .from("posts")
            .delete()
            .eq("id", value: postId)
            .eq("user_id", value: user.id)
            .select("id")
            .single()
            .execute()
    }
    
    func updatePost(postId: UUID, content: String) async throws -> Post {
        
        let user = try await client.auth.session.user
        
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        return try await client
            .from("posts")
            .update(["content": trimmedContent])
            .eq("id", value: postId)
            .eq("user_id", value: user.id)
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .single()
            .execute()
            .value
    }
    
    func fetchPosts(projectId: UUID) async throws -> [Post] {
        
        try await client
            .from("posts")
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .eq("project_id", value: projectId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func movePost(
        postId: UUID,
        to projectId: UUID?
    ) async throws {
        
        let user = try await client.auth.session.user
        
        try await client
            .from("posts")
            .update(PostProjectChange(projectId: projectId))
            .eq("id", value: postId)
            .eq("user_id", value: user.id)
            .select("id")
            .single()
            .execute()
    }
    
    func setPostHidden(
        postId: UUID,
        hidden: Bool
    ) async throws {
        
        let user = try await client.auth.session.user
        
        try await client
            .from("posts")
            .update(["is_hidden": hidden])
            .eq("id", value: postId)
            .eq("user_id", value: user.id)
            .select("id")
            .single()
            .execute()
    }
    
    // MARK: - Personalized Following Feed
    
    func fetchcPosts(
        userIds: [UUID],
        maxPosts: Int = 100
    ) async throws -> [Post] {
        
        try await fetchPosts(
            matching: "user_id",
            ids: userIds,
            maxPosts: maxPosts
        )
    }
    
    func fetchPosts(
        projectIds: [UUID],
        maxPosts: Int = 100
    ) async throws -> [Post] {
        
        try await fetchPosts(
            matching: "project_id",
            ids: projectIds,
            maxPosts: maxPosts
        )
    }
    
    // Split large follow lists into smaller requests.
    // This avoids creating extremely long query URLs.
    
    private func fetchPosts(
        matching column: String,
        ids: [UUID],
        maxPosts: Int
    ) async throws -> [Post] {
        
        guard !ids.isEmpty, maxPosts > 0 else {
            return []
        }
        
        let batchSize = 40
        var collectedPosts: [Post] = []
        
        for startIndex in stride(
            from: 0,
            to: ids.count,
            by: batchSize
        ) {
            
            try Task.checkCancellation()
            
            let endIndex = min(
                startIndex + batchSize,
                ids.count
            )
            
            let batchIDs = ids[startIndex..<endIndex]
                .map(\.uuidString)
            
            let batchPosts: [Post] = try await client
                .from("posts")
                .select("""
                    *,
                    author: profiles!posts_profile_fkey(
                        id,
                        display_name,
                        username
                    ),
                    project: projects!posts_project_owner_fk(
                        id,
                        name
                    )
                    """)
                .in(column, values: batchIDs)
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(maxPosts)
                .execute()
                .value
            
            collectedPosts.append(
                contentsOf: batchPosts
            )
        }
        
        return collectedPosts
    }
    
    // MARK: - Post Detail
    
    // MARK: - Post Detail

    func fetchPost(postId: UUID) async throws -> Post? {

        let posts: [Post] = try await client
            .from("posts")
            .select("""
                *,
                author: profiles!posts_profile_fkey(
                    id,
                    display_name,
                    username
                ),
                project: projects!posts_project_owner_fk(
                    id,
                    name
                )
                """)
            .eq("id", value: postId)
            .limit(1)
            .execute()
            .value

        return posts.first
    }
    
}

private struct NewPost: Encodable {
    
    let userId: UUID
    let content: String
    let projectId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case content
        case projectId = "project_id"
    }
}

private struct PostProjectChange: Encodable {
    
    let projectId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
    }
    
    func encode(to encoder: any Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let projectId {
            try container.encode(
                projectId,
                forKey: .projectId
            )
        } else {
            try container.encodeNil(forKey: .projectId)
        }
    }
}
