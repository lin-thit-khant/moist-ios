//
//  ModerationService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation
import Supabase

struct ModerationService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Current User

    func currentUserId() async throws -> UUID {

        let user = try await client.auth.session.user

        return user.id
    }

    // MARK: - Check Authorization

    func isModerator() async throws -> Bool {

        let result: Bool = try await client
            .rpc("rawdea_is_moderator")
            .execute()
            .value

        return result
    }

    // MARK: - Fetch Queue

    func fetchQueue(
        status: ModerationStatus,
        after cursor: ModerationCursor?,
        batchSize: Int = 21
    ) async throws -> [ModerationQueueItem] {

        let parameters = ModerationQueueParameters(
            status: status.rawValue,
            afterCreatedAt: cursor?.createdAt,
            afterId: cursor?.id,
            limit: batchSize
        )

        let items: [ModerationQueueItem] = try await client
            .rpc(
                "rawdea_moderation_queue",
                params: parameters
            )
            .execute()
            .value

        return items
    }

    // MARK: - Fetch Report Details

    func fetchReport(
        reportId: UUID
    ) async throws -> ModerationReportDetail? {

        let parameters = ModerationReportParameters(
            reportId: reportId
        )

        let results: [ModerationReportDetail] = try await client
            .rpc(
                "rawdea_moderation_detail",
                params: parameters
            )
            .execute()
            .value

        return results.first
    }

    // MARK: - Fetch Review History

    func fetchHistory(
        reportId: UUID
    ) async throws -> [ModerationReviewEvent] {

        let parameters = ModerationReportParameters(
            reportId: reportId
        )

        let results: [ModerationReviewEvent] = try await client
            .rpc(
                "rawdea_moderation_history",
                params: parameters
            )
            .execute()
            .value

        return results
    }

    // MARK: - Review Action

    @discardableResult
    func performAction(
        reportId: UUID,
        action: ModerationAction,
        note: String? = nil
    ) async throws -> String {

        let parameters = ModerationActionParameters(
            reportId: reportId,
            action: action.rawValue,
            note: note
        )

        let newStatus: String = try await client
            .rpc(
                "rawdea_moderation_action",
                params: parameters
            )
            .execute()
            .value

        return newStatus
    }
}

// MARK: - Private RPC Parameters

private struct ModerationQueueParameters: Encodable {

    let status: String
    let afterCreatedAt: String?
    let afterId: UUID?
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case status = "p_status"
        case afterCreatedAt = "p_after_created_at"
        case afterId = "p_after_id"
        case limit = "p_limit"
    }
}

private struct ModerationReportParameters: Encodable {

    let reportId: UUID

    enum CodingKeys: String, CodingKey {
        case reportId = "p_report_id"
    }
}

private struct ModerationActionParameters: Encodable {

    let reportId: UUID
    let action: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case reportId = "p_report_id"
        case action = "p_action"
        case note = "p_note"
    }
}
