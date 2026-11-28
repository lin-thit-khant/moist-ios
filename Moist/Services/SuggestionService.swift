//
//  SuggestionService.swift
//  Rawdea
//

import Foundation
import Supabase

protocol SuggestionServicing {
    func suggest(projectId: UUID, kind: PostKind, content: String) async throws
    func fetchWaiting(projectId: UUID) async throws -> [ProjectSuggestion]
    func fetchMine(projectId: UUID?) async throws -> [ProjectSuggestion]
    func withdraw(id: UUID) async throws
    func decide(id: UUID, approve: Bool) async throws
    func block(userId: UUID) async throws
}

struct SuggestionService: SuggestionServicing {

    private static let selection = """
        *,
        author: profiles!project_suggestions_user_id_fkey(id, display_name, username),
        project: projects!project_suggestions_project_id_fkey(name)
        """

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    func suggest(projectId: UUID, kind: PostKind, content: String) async throws {
        try await client
            .rpc("rawdea_suggest", params: [
                "p_project_id": projectId.uuidString,
                "p_kind": kind.rawValue,
                "p_content": content
            ])
            .execute()
    }

    /// Waiting suggestions for a Project the viewer owns, oldest first.
    func fetchWaiting(projectId: UUID) async throws -> [ProjectSuggestion] {
        await closeExpired()
        let userId = try await client.auth.session.user.id
        return try await client
            .from("project_suggestions")
            .select(Self.selection)
            .eq("project_id", value: projectId)
            .eq("status", value: SuggestionStatus.waiting.rawValue)
            .neq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// The viewer's own suggestions, newest first.
    func fetchMine(projectId: UUID? = nil) async throws -> [ProjectSuggestion] {
        await closeExpired()
        let userId = try await client.auth.session.user.id
        var query = client
            .from("project_suggestions")
            .select(Self.selection)
            .eq("user_id", value: userId)
        if let projectId {
            query = query.eq("project_id", value: projectId)
        }
        return try await query
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func withdraw(id: UUID) async throws {
        try await client
            .rpc("rawdea_withdraw_suggestion", params: ["p_id": id.uuidString])
            .execute()
    }

    func decide(id: UUID, approve: Bool) async throws {
        try await client
            .rpc("rawdea_decide_suggestion", params: DecisionRequest(id: id, approve: approve))
            .execute()
    }

    func block(userId: UUID) async throws {
        try await BlockService(client: client).blockUser(userId: userId)
    }

    // The list still reads if this fails; the server refuses
    // to answer an expired suggestion.
    private func closeExpired() async {
        _ = try? await client
            .rpc("rawdea_close_expired_suggestions")
            .execute()
    }
}

private struct DecisionRequest: Encodable {
    let id: UUID
    let approve: Bool

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case approve = "p_approve"
    }
}
