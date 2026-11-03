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
    
    func createPost(content: String) async throws -> Post {
        
        let user = try await client.auth.session.user
        
        let newPost = NewPost(
            userId: user.id,
            content: content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
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
                )
                """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
}

private struct NewPost: Encodable {
    
    let userId: UUID
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case content
    }
}
