//
//  HeldPostService.swift
//  Rawdea
//

import Foundation
import Supabase

/// Posts waiting for a moderator. The server enforces every rule.
struct HeldPostService {

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    // MARK: - Author

    func hold(
        content: String,
        projectId: UUID?,
        kind: PostKind
    ) async throws -> HoldReason {

        var parameters: [String: String] = [
            "p_content": content,
            "p_kind": kind.rawValue
        ]
        parameters["p_project_id"] = projectId?.uuidString

        return try await client
            .rpc("rawdea_hold_post", params: parameters)
            .execute()
            .value
    }

    func fetchMine() async throws -> [HeldPostNotice] {
        try await client
            .rpc("rawdea_my_held_posts")
            .execute()
            .value
    }

    func markSeen() async throws {
        try await client
            .rpc("rawdea_mark_held_seen")
            .execute()
    }

    func askForSecondLook(id: UUID) async throws {
        try await client
            .rpc("rawdea_appeal_held_post", params: ["p_id": id.uuidString])
            .execute()
    }

    // MARK: - Moderator

    func fetchQueue() async throws -> [HeldQueueItem] {
        try await client
            .rpc("rawdea_moderation_held_queue")
            .execute()
            .value
    }

    func decide(id: UUID, approve: Bool) async throws {
        try await client
            .rpc(
                "rawdea_moderation_decide_held",
                params: HeldDecision(id: id, approve: approve)
            )
            .execute()
    }
}

private struct HeldDecision: Encodable {

    let id: UUID
    let approve: Bool

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case approve = "p_approve"
    }
}
