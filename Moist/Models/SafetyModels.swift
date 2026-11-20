//
//  SafetyModels.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import Foundation

enum SafetyRequestKind: String, CaseIterable, Identifiable {
    case support
    case appeal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .support:
            return "General Support"
        case .appeal:
            return "Appeal a Moderation Decision"
        }
    }
}

enum SafetyInboxStatus: String, CaseIterable, Identifiable {
    case open
    case resolved

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct SafetyRequest: Decodable, Identifiable {
    let id: UUID
    let kind: String
    let message: String
    let status: String
    let response: String?
    let createdAt: Date
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, message, status, response
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}

struct ModerationSafetyRequest: Decodable, Identifiable {
    let id: UUID
    let requesterId: UUID
    let kind: String
    let message: String
    let status: String
    let response: String?
    let createdAt: Date
    let respondedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kind, message, status, response
        case requesterId = "requester_id"
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}
