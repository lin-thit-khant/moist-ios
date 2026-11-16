//
//  NotificationService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Supabase

struct NotificationService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Current User

    private func currentUserId() async throws -> UUID {

        let user = try await client.auth.session.user

        return user.id
    }

    // MARK: - Fetch Notifications

    func fetchNotifications(
        limit: Int = 100
    ) async throws -> [RawdeaNotification] {

        let userId = try await currentUserId()

        return try await client
            .from("notifications")
            .select("""
                id,
                recipient_id,
                actor_id,
                kind,
                post_id,
                project_id,
                is_read,
                created_at,
                actor:profiles!notifications_actor_id_fkey(
                    id,
                    display_name,
                    username
                )
                """)
            .eq("recipient_id", value: userId)
            .order("created_at", ascending: false)
            .order("id", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    // MARK: - Unread Count

    func fetchUnreadCount() async throws -> Int {

        let userId = try await currentUserId()

        let response = try await client
            .from("notifications")
            .select(
                "*",
                head: true,
                count: .exact
            )
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()

        return response.count ?? 0
    }

    // MARK: - Mark One as Read

    func markAsRead(
        notificationId: UUID
    ) async throws {

        let userId = try await currentUserId()

        try await client
            .from("notifications")
            .update(["is_read": true])
            .eq("id", value: notificationId)
            .eq("recipient_id", value: userId)
            .select("id")
            .single()
            .execute()
    }

    // MARK: - Mark All as Read

    func markAllAsRead() async throws {

        let userId = try await currentUserId()

        try await client
            .from("notifications")
            .update(["is_read": true])
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }
}
