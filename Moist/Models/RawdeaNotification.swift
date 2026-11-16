//
//  RawdeaNotification.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation

enum RawdeaNotificationKind: String, Decodable {

    case userFollow = "user_follow"
    case projectFollow = "project_follow"
    case postLike = "post_like"
    case postComment = "post_comment"

    var systemImage: String {

        switch self {

        case .userFollow:
            return "person.crop.circle.badge.plus"

        case .projectFollow:
            return "folder"

        case .postLike:
            return "heart"

        case .postComment:
            return "bubble.left"
        }
    }
}

struct RawdeaNotification: Identifiable, Decodable {

    let id: UUID
    let recipientId: UUID
    let actorId: UUID

    let kind: RawdeaNotificationKind

    let postId: UUID?
    let projectId: UUID?

    var isRead: Bool

    let createdAt: Date

    let actor: PostAuthor?

    enum CodingKeys: String, CodingKey {

        case id

        case recipientId = "recipient_id"
        case actorId = "actor_id"

        case kind

        case postId = "post_id"
        case projectId = "project_id"

        case isRead = "is_read"
        case createdAt = "created_at"

        case actor
    }

    // MARK: - Display

    var actorName: String {

        let displayName = actor?.displayName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        if !displayName.isEmpty {
            return displayName
        }

        return actor?.username ?? "Someone"
    }

    var message: String {

        switch kind {

        case .userFollow:
            return "\(actorName) started following you"

        case .projectFollow:
            return "\(actorName) followed your Project"

        case .postLike:
            return "\(actorName) liked your post"

        case .postComment:
            return "\(actorName) commented on your post"
        }
    }
}
