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
    case suggestionsWaiting = "suggestions_waiting"
    case suggestionApproved = "suggestion_approved"
    case suggestionDeclined = "suggestion_declined"
    case contributorInvite = "contributor_invite"
    case contributorPrompt = "contributor_prompt"
    case credited
    case cycleStarted = "cycle_started"
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
    var project: NotificationProject? = nil
}

struct NotificationComment: Decodable {
    let content: String
}

struct NotificationProject: Decodable {
    let name: String
    var cycleName: String? = nil
    var cycle: Int? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case cycleName = "cycle_name"
        case cycle
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

    var stage: ProjectStage? = nil
    var post: NotificationPost? = nil
    var comment: NotificationComment? = nil
    var project: NotificationProject? = nil
    var itemCount: Int? = nil

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
        case comment
        case itemCount = "item_count"
    }

    // MARK: - Display

    var actorName: String {
        actor?.username ?? "Someone"
    }

        private var isAnswer: Bool {
        kind == .postComment && post?.kind == .question
    }

    /// Rows about a Project are named and drawn by it.
    var isAboutProject: Bool {
        switch kind {
        case .stageChange, .suggestionsWaiting, .suggestionDeclined,
             .credited, .cycleStarted:
            return true
        default:
            return false
        }
    }

    /// Who the row is about.
    var subject: String {
        isAboutProject ? (project?.name ?? "A Project") : actorName
    }

    /// What happened, following the subject.
    var action: String {

        switch kind {

        case .userFollow:
            return "started following you"

        case .projectFollow:
            return "started following \(project?.name ?? "your Project")"

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

        case .suggestionsWaiting:
            let count = itemCount ?? 1
            return count == 1
                ? "has 1 new suggestion"
                : "has \(count) new suggestions"

        case .suggestionApproved:
            return "approved your suggestion for \(project?.name ?? "a Project")"

        case .suggestionDeclined:
            return "didn't use your suggestion this time"

        case .contributorInvite:
            return "invited you to contribute to \(project?.name ?? "a Project")"

        case .contributorPrompt:
            return "has 3 approved suggestions in \(project?.name ?? "your Project")"

        case .credited:
            return "moved to \(stage?.title ?? "a new stage"). You're credited."

        case .cycleStarted:
            let number = itemCount ?? 2
            // The name belongs to the current cycle only.
            let name = project?.cycle == number ? project?.cycleName : nil
            return "started \(ProjectCycle.title(number, name: name))"
        }
    }

    var message: String {
        "\(subject) \(action)"
    }

    var detail: String? {

        switch kind {

        case .stageChange:
            return "A Project you follow"

        case .suggestionsWaiting:
            return "Approve or decline them"

        case .suggestionDeclined:
            return "Nothing was made public"

        case .contributorInvite:
            return "Accept or decline"

        case .contributorPrompt:
            return "Invite as contributor"

        case .credited:
            return "Thanks for helping"

        case .cycleStarted:
            return "You helped before"

        case .postComment:
            return comment.map { "“\($0.content)”" } ?? post?.content

        case .bestAnswer:
            guard let post else { return nil }
            guard let name = post.project?.name else { return post.content }
            return "\(name) · \(post.content)"

        default:
            return post?.content
        }
    }

    func matches(_ filter: RawdeaActivityFilter) -> Bool {

        switch filter {
        case .all:
            return true
        case .answers:
            return kind == .bestAnswer || isAnswer
        case .projects:
            return [
                .stageChange, .projectFollow, .suggestionsWaiting,
                .suggestionApproved, .suggestionDeclined,
                .contributorInvite, .contributorPrompt, .credited,
                .cycleStarted
            ].contains(kind)
        case .likes:
            return kind == .postLike || kind == .userFollow
        }
    }
}

/// One Activity row. Likes on the same post share a row.
struct RawdeaActivityGroup: Identifiable {

    let notifications: [RawdeaNotification]

    var latest: RawdeaNotification { notifications[0] }
    var id: UUID { latest.id }
    var isRead: Bool { notifications.allSatisfy(\.isRead) }

    /// "soe and 13 others" when several people liked one post.
    var subject: String {
        let others = Set(notifications.map(\.actorId)).count - 1
        switch others {
        case ..<1: return latest.subject
        case 1: return "\(latest.subject) and 1 other"
        default: return "\(latest.subject) and \(others) others"
        }
    }

    /// Keeps the newest-first order of what it is given.
    static func grouping(
        _ notifications: [RawdeaNotification]
    ) -> [RawdeaActivityGroup] {

        var order: [String] = []
        var groups: [String: [RawdeaNotification]] = [:]

        for item in notifications {
            let key = item.kind == .postLike
                ? "like-\(item.postId?.uuidString ?? item.id.uuidString)"
                : item.id.uuidString
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(item)
        }

        return order.compactMap { groups[$0].map(RawdeaActivityGroup.init) }
    }
}
