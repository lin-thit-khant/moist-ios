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
