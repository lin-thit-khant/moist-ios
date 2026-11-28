//
//  ProjectMember.swift
//  Rawdea
//

import Foundation

enum MemberStatus: String, Codable {
    case invited, active, declined, left, removed
}

/// Someone's place in a Project they don't own.
struct ProjectMember: Identifiable, Decodable {

    let projectId: UUID
    let userId: UUID
    var status: MemberStatus
    var person: PostAuthor? = nil

    var id: UUID { userId }

    /// Invited and active people together.
    static let limit = 5

    var holdsPlace: Bool {
        status == .invited || status == .active
    }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case userId = "user_id"
        case status, person
    }
}

/// Someone with an approved suggestion, who may be invited.
struct ContributorCandidate: Identifiable {
    let userId: UUID
    let username: String
    let approvedCount: Int

    var id: UUID { userId }

    /// Everyone with an approved suggestion who holds no place,
    /// most helpful first.
    static func from(
        approved: [ProjectSuggestion],
        members: [ProjectMember]
    ) -> [ContributorCandidate] {
        let taken = Set(members.filter(\.holdsPlace).map(\.userId))
        return Dictionary(grouping: approved, by: \.userId)
            .filter { !taken.contains($0.key) }
            .map { userId, suggestions in
                ContributorCandidate(
                    userId: userId,
                    username: suggestions.first?.author?.username ?? "someone",
                    approvedCount: suggestions.count
                )
            }
            .sorted {
                ($1.approvedCount, $0.username) < ($0.approvedCount, $1.username)
            }
    }
}

/// A Project on someone's "Contributed to" list.
struct ContributedProject: Identifiable, Decodable {

    let projectId: UUID
    let projectName: String
    let ownerUsername: String
    let isContributor: Bool
    var cycles: [Int]? = nil

    var id: UUID { projectId }

    var role: String { isContributor ? "contributor" : "suggested" }

    var detail: String {
        let list = cycles ?? []
        let when = list.isEmpty
            ? ""
            : " · \(list.count == 1 ? "Cycle" : "Cycles") \(list.map(String.init).joined(separator: ", "))"
        return "by \(ownerUsername)\(when) · \(role)"
    }

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case projectName = "project_name"
        case ownerUsername = "owner_username"
        case isContributor = "is_contributor"
        case cycles
    }
}

/// "maya", "maya and ravi", "maya, tom and ravi".
enum CreditNames {

    static func sentence(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        guard names.count > 1 else { return last }
        return "\(names.dropLast().joined(separator: ", ")) and \(last)"
    }
}
