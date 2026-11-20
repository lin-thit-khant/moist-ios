//
//  SafetyService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import Foundation
import Supabase

struct SafetyService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Submit Support / Appeal

    func submit(
        kind: SafetyRequestKind,
        message: String
    ) async throws -> UUID {

        let params = SubmitSafetyParameters(
            kind: kind.rawValue,
            message: message
        )

        let id: UUID = try await client
            .rpc(
                "rawdea_submit_safety_request",
                params: params
            )
            .execute()
            .value

        return id
    }

    // MARK: - Read My Requests

    func myRequests() async throws -> [SafetyRequest] {

        try await client
            .rpc("rawdea_my_safety_requests")
            .execute()
            .value
    }

    // MARK: - Moderator Inbox

    func inbox(
        status: SafetyInboxStatus
    ) async throws -> [ModerationSafetyRequest] {

        let params = SafetyInboxParameters(
            status: status.rawValue,
            limit: 100
        )

        return try await client
            .rpc(
                "rawdea_moderation_safety_inbox",
                params: params
            )
            .execute()
            .value
    }

    // MARK: - Respond to Request

    func respond(
        requestId: UUID,
        response: String
    ) async throws {

        let params = SafetyReplyParameters(
            requestId: requestId,
            response: response
        )

        try await client
            .rpc(
                "rawdea_moderation_reply_safety",
                params: params
            )
            .execute()
    }

    // MARK: - Delete Own Account

    func deleteMyAccount() async throws {

        try await client
            .rpc(
                "rawdea_delete_my_account",
                params: DeletionParameters(
                    confirmation: "DELETE"
                )
            )
            .execute()
    }
}

// MARK: - RPC Parameters

private struct SubmitSafetyParameters: Encodable {
    let kind: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case kind = "p_kind"
        case message = "p_message"
    }
}

private struct SafetyInboxParameters: Encodable {
    let status: String
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case status = "p_status"
        case limit = "p_limit"
    }
}

private struct SafetyReplyParameters: Encodable {
    let requestId: UUID
    let response: String

    enum CodingKeys: String, CodingKey {
        case requestId = "p_request_id"
        case response = "p_response"
    }
}

private struct DeletionParameters: Encodable {
    let confirmation: String

    enum CodingKeys: String, CodingKey {
        case confirmation = "p_confirmation"
    }
}
