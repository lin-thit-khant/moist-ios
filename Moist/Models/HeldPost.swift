//
//  HeldPost.swift
//  Rawdea
//

import Foundation

/// Why the server asked for a check before publishing.
enum HoldReason: String, Decodable {

    case possibleInsult = "possible_insult"
    case severalLinks = "several_links"
    case newAccountLink = "new_account_link"

    var text: String {
        switch self {
        case .possibleInsult: "Possible insult toward other people."
        case .severalLinks: "Several links in one post."
        case .newAccountLink: "Links from new accounts are checked first."
        }
    }

    /// The reason carried by a refused insert, if that is what failed.
    static func from(_ error: Error) -> HoldReason? {
        let details = "\(error.localizedDescription) \(String(reflecting: error))"
        guard let marker = details.range(of: "RAWDEA_FILTER_HELD:") else {
            return nil
        }
        let code = details[marker.upperBound...]
            .prefix { $0.isLetter || $0 == "_" }
        return HoldReason(rawValue: String(code))
    }
}

/// One of the signed-in person's held posts, once there is news about it.
struct HeldPostNotice: Identifiable, Decodable, Equatable {

    enum Status: String, Decodable {
        case pending
        case approved
        case removed
    }

    let id: UUID
    let content: String
    let reason: HoldReason
    let status: Status
    let appealed: Bool
    var seen: Bool

    var title: String {
        status == .approved ? "Your post is live" : "Your post was removed"
    }

    var message: String {
        switch status {
        case .approved:
            "A moderator approved it."
        case .removed where appealed:
            "A moderator looked again. It stays removed."
        case .removed:
            "It broke the rule: \(reason.text) You can ask for a second look."
        case .pending:
            "It broke the rule: \(reason.text)"
        }
    }

    var canAskAgain: Bool { status == .removed && !appealed }

    /// Waiting for the second decision.
    var isSecondLookRequested: Bool { status == .pending && appealed }
}

/// A held post as the moderator sees it.
struct HeldQueueItem: Identifiable, Decodable {

    let id: UUID
    let content: String
    let reason: HoldReason
    let username: String
    let accountCreatedAt: Date
    let appealed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case reason
        case username
        case accountCreatedAt = "account_created_at"
        case appealed
    }

    func accountAge(at now: Date = .now) -> String {
        let days = max(0, Int(now.timeIntervalSince(accountCreatedAt) / 86_400))
        switch days {
        case 0: return "New today"
        case 1: return "1 day old"
        default: return "\(days) days old"
        }
    }
}
