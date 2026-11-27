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
                stage,
                post:posts!notifications_post_id_fkey(
                    kind,
                    content
                ),
                project:projects!notifications_project_id_fkey(
                    name
                ),
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

// MARK: - Preferences

/// Which notifications the server creates for this account.
struct NotificationPreferences: Codable, Equatable {

    var answers = true
    var stageChanges = true
    var likes = true

    enum CodingKeys: String, CodingKey {
        case answers
        case stageChanges = "stage_changes"
        case likes
    }
}

extension NotificationService {

    func fetchPreferences() async throws -> NotificationPreferences {

        let userId = try await client.auth.session.user.id

        // No row yet means everything is on.
        let rows: [NotificationPreferences] = try await client
            .from("notification_preferences")
            .select("answers, stage_changes, likes")
            .eq("user_id", value: userId)
            .execute()
            .value

        return rows.first ?? NotificationPreferences()
    }

    func savePreferences(
        _ preferences: NotificationPreferences
    ) async throws {

        let userId = try await client.auth.session.user.id

        try await client
            .from("notification_preferences")
            .upsert(
                NotificationPreferencesRow(
                    userId: userId,
                    answers: preferences.answers,
                    stageChanges: preferences.stageChanges,
                    likes: preferences.likes
                ),
                onConflict: "user_id",
                returning: .minimal
            )
            .execute()
    }
}

private struct NotificationPreferencesRow: Encodable {

    let userId: UUID
    let answers: Bool
    let stageChanges: Bool
    let likes: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case answers
        case stageChanges = "stage_changes"
        case likes
    }
}
