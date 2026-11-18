//
//  BlockService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 17/11/2569 BE.
//


import Foundation
import Supabase

struct BlockService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Authentication

    private func currentUserId() async throws -> UUID {

        let user = try await client.auth.session.user

        return user.id
    }

    // MARK: - Check Existing Block

    func isBlocked(
        userId: UUID
    ) async throws -> Bool {

        let viewerId = try await currentUserId()

        let records: [BlockedUserID] = try await client
            .from("user_blocks")
            .select("blocked_id")
            .eq("blocker_id", value: viewerId)
            .eq("blocked_id", value: userId)
            .limit(1)
            .execute()
            .value

        return !records.isEmpty
    }

    // MARK: - Fetch Blocked Accounts

    func fetchBlockedUsers() async throws -> [BlockedUser] {

        let viewerId = try await currentUserId()

        return try await client
            .from("user_blocks")
            .select("""
                blocked_id,
                blocked_username,
                blocked_display_name,
                created_at
            """)
            .eq("blocker_id", value: viewerId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Block Account

    func blockUser(
        userId: UUID
    ) async throws {

        let request = BlockUserRequest(
            targetUserId: userId
        )

        try await client
            .rpc(
                "rawdea_block_user",
                params: request
            )
            .execute()
    }

    // MARK: - Unblock Account

    func unblockUser(
        userId: UUID
    ) async throws {

        let request = BlockUserRequest(
            targetUserId: userId
        )

        try await client
            .rpc(
                "rawdea_unblock_user",
                params: request
            )
            .execute()
    }
}

// MARK: - Database Response

private struct BlockedUserID: Decodable {

    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
    }
}

// MARK: - Database Request

private struct BlockUserRequest: Encodable {

    let targetUserId: UUID

    enum CodingKeys: String, CodingKey {
        case targetUserId = "target_user_id"
    }
}
