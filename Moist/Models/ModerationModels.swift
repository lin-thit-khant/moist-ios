//
//  ModerationModels.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation

// MARK: - Moderation Status

enum ModerationStatus: String, CaseIterable, Identifiable {

    case pending
    case reviewing
    case dismissed

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

// MARK: - Pagination Cursor

struct ModerationCursor: Equatable {

    let createdAt: String
    let id: UUID
}

// MARK: - Queue Item

struct ModerationQueueItem: Identifiable, Decodable {

    let id: UUID

    let targetType: String
    let reason: String
    let status: String

    let evidenceUsername: String?

    let createdAt: Date
    let createdAtCursor: String

    let reviewerId: UUID?

    var cursor: ModerationCursor {
        ModerationCursor(
            createdAt: createdAtCursor,
            id: id
        )
    }

    var reasonTitle: String {
        ReportReason(rawValue: reason)?.title ?? reason
    }

    var targetTitle: String {
        targetType.capitalized
    }

    enum CodingKeys: String, CodingKey {
        case id
        case targetType = "target_type"
        case reason
        case status
        case evidenceUsername = "evidence_username"
        case createdAt = "created_at"
        case createdAtCursor = "created_at_cursor"
        case reviewerId = "reviewer_id"
    }
}

// MARK: - Report Details

struct ModerationReportDetail: Identifiable, Decodable {

    let id: UUID

    let reporterId: UUID
    let subjectUserId: UUID

    let targetType: String
    let targetId: UUID

    let reason: String
    let explanation: String?

    let evidenceText: String?
    let evidenceUsername: String?

    let status: String
    let createdAt: Date

    let reviewerId: UUID?
    let reviewedAt: Date?
    let resolutionNote: String?

    var reasonTitle: String {
        ReportReason(rawValue: reason)?.title ?? reason
    }

    enum CodingKeys: String, CodingKey {
        case id
        case reporterId = "reporter_id"
        case subjectUserId = "subject_user_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case reason
        case explanation
        case evidenceText = "evidence_text"
        case evidenceUsername = "evidence_username"
        case status
        case createdAt = "created_at"
        case reviewerId = "reviewer_id"
        case reviewedAt = "reviewed_at"
        case resolutionNote = "resolution_note"
    }
}

// MARK: - Audit History

struct ModerationReviewEvent: Identifiable, Decodable {

    let id: UUID
    let moderatorId: UUID

    let action: String
    let previousStatus: String
    let newStatus: String

    let note: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case moderatorId = "moderator_id"
        case action
        case previousStatus = "previous_status"
        case newStatus = "new_status"
        case note
        case createdAt = "created_at"
    }
}

// MARK: - Review Actions

enum ModerationAction: String {

    case claim
    case release
    case dismiss
    case reopen
}
