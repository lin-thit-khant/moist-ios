//
//  ProjectSuggestion.swift
//  Rawdea
//

import Foundation

enum SuggestionStatus: String, Codable {
    case waiting, approved, declined, withdrawn, closed

    var title: String { rawValue.capitalized }
}

/// An update a follower offered to a Project.
struct ProjectSuggestion: Identifiable, Decodable {

    struct Source: Decodable {
        let name: String
    }

    let id: UUID
    let projectId: UUID
    let userId: UUID
    let kind: PostKind
    let content: String
    var status: SuggestionStatus
    var postId: UUID? = nil
    let createdAt: Date
    var author: PostAuthor? = nil
    var project: Source? = nil

    /// Followers suggest these. Decisions stay with the owner.
    static let kinds: [PostKind] = [.note, .question, .progress]

    static let waitingLimit = 3

    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case userId = "user_id"
        case kind, content, status
        case postId = "post_id"
        case createdAt = "created_at"
        case author, project
    }
}
