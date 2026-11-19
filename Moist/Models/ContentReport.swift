//
//  ContentReport.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation

// MARK: - Report Target Type

enum ReportTargetType: String, Codable {
    case post
    case comment
    case account
}

// MARK: - Report Target

enum ReportTarget: Identifiable, Equatable {

    case post(UUID)
    case comment(UUID)
    case account(UUID)

    var targetType: ReportTargetType {
        switch self {
        case .post:
            return .post
        case .comment:
            return .comment
        case .account:
            return .account
        }
    }

    var targetId: UUID {
        switch self {
        case .post(let id),
             .comment(let id),
             .account(let id):
            return id
        }
    }

    var id: String {
        "\(targetType.rawValue):\(targetId.uuidString)"
    }

    var displayName: String {
        switch self {
        case .post:
            return "Post"
        case .comment:
            return "Comment"
        case .account:
            return "Account"
        }
    }
}

// MARK: - Report Reasons

enum ReportReason: String, CaseIterable, Identifiable {

    case spam
    case harassment
    case hate
    case sexualContent = "sexual_content"
    case violence
    case selfHarm = "self_harm"
    case other

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .spam:
            return "Spam or misleading content"
        case .harassment:
            return "Bullying or harassment"
        case .hate:
            return "Hate or discrimination"
        case .sexualContent:
            return "Sexual or explicit content"
        case .violence:
            return "Violence or threats"
        case .selfHarm:
            return "Self-harm or dangerous behavior"
        case .other:
            return "Something else"
        }
    }
}
