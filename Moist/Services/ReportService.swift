//
//  ReportService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation
import Supabase

struct ReportService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client
    ) {
        self.client = client
    }

    // MARK: - Submit Report

    func submitReport(
        target: ReportTarget,
        reason: ReportReason,
        explanation: String
    ) async throws -> UUID {

        let cleanedExplanation = explanation
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let request = SubmitReportRequest(
            targetType: target.targetType.rawValue,
            targetId: target.targetId,
            reason: reason.rawValue,
            explanation: cleanedExplanation.isEmpty
                ? nil
                : cleanedExplanation
        )

        let reportId: UUID = try await client
            .rpc(
                "rawdea_submit_report",
                params: request
            )
            .execute()
            .value

        return reportId
    }
}

// MARK: - RPC Parameters

private struct SubmitReportRequest: Encodable {

    let targetType: String
    let targetId: UUID
    let reason: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case targetType = "p_target_type"
        case targetId = "p_target_id"
        case reason = "p_reason"
        case explanation = "p_explanation"
    }
}
