//
//  FollowingService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 12/11/2569 BE.
//

import Foundation
import Supabase

struct FollowingService {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }
    
    // MARK: - Authentication
    
    func currentUserId() async throws -> UUID {
        let user = try await client.auth.session.user
        return user.id
    }

    // MARK: - User Following
    
    func isFollowingUser(userId: UUID) async throws -> Bool {
        
        let viewerId = try await currentUserId()
        
        let records: [FollowPresence] = try await client
            .from("user_follows")
            .select("follower_id")
            .eq("follower_id", value: viewerId)
            .eq("followed_user_id", value: userId)
            .limit(1)
            .execute()
            .value
        
        return !records.isEmpty
    }
    
    func followUser(userId: UUID) async throws {
        
        let viewerId = try await currentUserId()
        
        let newFollow = NewUserFollow(
            followerId: viewerId,
            followedUserId: userId
        )
        
        try await client
            .from("user_follows")
            .insert(newFollow)
            .execute()
    }
    
    func unfollowUser(userId: UUID) async throws {
        
        let viewerId = try await currentUserId()
        
        try await client
            .from("user_follows")
            .delete()
            .eq("follower_id", value: viewerId)
            .eq("followed_user_id", value: userId)
            .execute()
    }
    
    func userFollowerCount(userId: UUID) async throws -> Int {
        
        let response = try await client
            .from("user_follows")
            .select("*", head: true, count: .exact)
            .eq("followed_user_id", value: userId)
            .execute()
        
        return response.count ?? 0
    }
    
    func userFollowingCount(userId: UUID) async throws -> Int {
        
        let response = try await client
            .from("user_follows")
            .select("*", head: true, count: .exact)
            .eq("follower_id", value: userId)
            .execute()
        
        return response.count ?? 0
    }
    
    // MARK: - Project Following
    
    func isFollowingProject(projectId: UUID) async throws -> Bool {
        
        let viewerId = try await currentUserId()
        
        let records: [FollowPresence] = try await client
            .from("project_follows")
            .select("follower_id")
            .eq("follower_id", value: viewerId)
            .eq("project_id", value: projectId)
            .limit(1)
            .execute()
            .value
        
        return !records.isEmpty
    }
    
    func followProject(projectId: UUID) async throws {
        
        let viewerId = try await currentUserId()
        
        let newFollow = NewProjectFollow(
            followerId: viewerId,
            projectId: projectId
        )
        
        try await client
            .from("project_follows")
            .insert(newFollow)
            .execute()
    }
    
    func unfollowProject(projectId: UUID) async throws {
        
        let viewerId = try await currentUserId()
        
        try await client
            .from("project_follows")
            // Returning rows would need every column, and
            // last_seen_at is not readable.
            .delete(returning: .minimal)
            .eq("follower_id", value: viewerId)
            .eq("project_id", value: projectId)
            .execute()
    }
    
    func projectFollowerCount(projectId: UUID) async throws -> Int {
        
        let response = try await client
            .from("project_follows")
            .select("follower_id", head: true, count: .exact)
            .eq("project_id", value: projectId)
            .execute()
        
        return response.count ?? 0
    }
    
    // MARK: - Last Seen
    
    // The server records its own time.
    func markProjectSeen(projectId: UUID) async throws {
        
        let viewerId = try await currentUserId()
        
        try await client
            .from("project_follows")
            .update(["last_seen_at": "now"], returning: .minimal)
            .eq("follower_id", value: viewerId)
            .eq("project_id", value: projectId)
            .execute()
    }
    
    // Followed Projects that have been opened, by Project ID.
    func fetchProjectLastSeen() async throws -> [UUID: Date] {
        
        let records: [ProjectLastSeenRecord] = try await client
            .rpc("rawdea_followed_project_last_seen")
            .execute()
            .value
        
        return records.reduce(into: [:]) { result, record in
            result[record.projectId] = record.lastSeenAt
        }
    }
    
    // MARK: - Project Followers

    func fetchProjectFollowers(
        projectId: UUID
    ) async throws -> [PostAuthor] {

        let records: [ProjectFollowerRecord] = try await client
            .from("project_follows")
            .select("""
                profile:profiles!project_follows_follower_id_fkey(
                    id,
                    display_name,
                    username
                )
                """)
            .eq("project_id", value: projectId)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        return records.compactMap(\.profile)
    }

    // MARK: - Following Lists
    
    func fetchFollowingPeople() async throws -> [Profile] {
        
        let viewerId = try await currentUserId()
        
        let records: [FollowedPersonRecord] = try await client
            .from("user_follows")
            .select("""
                profile:profiles!user_follows_followed_user_id_fkey(
                    id,
                    username,
                    display_name,
                    bio,
                    created_at,
                    updated_at
                )
                """)
            .eq("follower_id", value: viewerId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return records.compactMap(\.profile)
    }
    
    func fetchFollowingProjects() async throws -> [Project] {
        
        let viewerId = try await currentUserId()
        
        let records: [FollowedProjectRecord] = try await client
            .from("project_follows")
            .select("""
                project:projects!project_follows_project_id_fkey(
                    id,
                    user_id,
                    name,
                    created_at,
                    is_archived,
                    is_hidden,
                    is_pinned,
                    stage,
                    stage_changed_at,
                    is_default,
                    description
                )
                """)
            .eq("follower_id", value: viewerId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return records
            .compactMap(\.project)
            .filter { !$0.isHidden && !$0.isArchived }
    }
}

// MARK: - Database Payloads

private struct NewUserFollow: Encodable {
    
    let followerId: UUID
    let followedUserId: UUID
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followedUserId = "followed_user_id"
    }
}

private struct NewProjectFollow: Encodable {
    
    let followerId: UUID
    let projectId: UUID
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case projectId = "project_id"
    }
}


// MARK: - Database Responses

private struct FollowPresence: Decodable {
    
    let followerId: UUID
    
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
    }
}

private struct ProjectFollowerRecord: Decodable {
    let profile: PostAuthor?
}

private struct ProjectLastSeenRecord: Decodable {
    
    let projectId: UUID
    let lastSeenAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case lastSeenAt = "last_seen_at"
    }
}

private struct FollowedPersonRecord: Decodable {
    let profile: Profile?
}

private struct FollowedProjectRecord: Decodable {
    let project: Project?
}
