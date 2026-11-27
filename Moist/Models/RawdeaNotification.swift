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
    case bestAnswer = "best_answer"
    case stageChange = "stage_change"
}

/// The Activity filters.
enum RawdeaActivityFilter: String, CaseIterable {

    case all
    case answers
    case projects
    case likes

    var title: String {
        rawValue.capitalized
    }
}

/// What a notification needs to know about its post.
struct NotificationPost: Decodable {
    let kind: PostKind
    let content: String
}

struct NotificationProject: Decodable {
    let name: String
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

    var stage: ProjectStage? = nil
    var post: NotificationPost? = nil
    var project: NotificationProject? = nil

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
        case stage
        case post
        case project
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

    private var isAnswer: Bool {
        kind == .postComment && post?.kind == .question
    }

    /// Who the row is about: the Project for a stage change.
    var subject: String {
        kind == .stageChange ? (project?.name ?? "A Project") : actorName
    }

    /// What happened, following the subject.
    var action: String {

        switch kind {

        case .userFollow:
            return "started following you"

        case .projectFollow:
            return "followed \(project?.name ?? "your Project")"

        case .postLike:
            guard let post else { return "liked your post" }
            return "liked your \(post.kind.title.lowercased()) post"

        case .postComment:
            return isAnswer
                ? "answered your question"
                : "commented on your post"

        case .bestAnswer:
            return "picked your answer as best"

        case .stageChange:
            return "moved to \(stage?.title ?? "a new stage")"
        }
    }

    var message: String {
        "\(subject) \(action)"
    }

    var detail: String? {
        kind == .stageChange ? "A Project you follow" : post?.content
    }

    func matches(_ filter: RawdeaActivityFilter) -> Bool {

        switch filter {
        case .all:
            return true
        case .answers:
            return kind == .bestAnswer || isAnswer
        case .projects:
            return kind == .stageChange || kind == .projectFollow
        case .likes:
            return kind == .postLike
        }
    }
}
