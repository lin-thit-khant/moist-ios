//
//  CollaborationErrorMessage.swift
//  Rawdea
//

import Foundation

/// Plain words for the server's collaboration refusals.
enum CollaborationErrorMessage {

    private static let messages: [(marker: String, text: String)] = [
        ("rawdea_suggest_unavailable",
         "This Project isn't taking suggestions from you right now."),
        ("rawdea_suggestion_limit",
         "You already have 3 suggestions waiting here. Wait for an answer or withdraw one."),
        ("rawdea_suggestion_needs_edit",
         "Suggestions can't include text that needs a check. Remove links or reword it."),
        ("rawdea_suggestion_changed",
         "This suggestion can no longer be answered. Pull to refresh."),
        ("rawdea_contributors_full",
         "A Project has room for 5 contributors, invitations included."),
        ("rawdea_invite_unavailable",
         "This invitation isn't possible right now."),
        ("rawdea_invite_changed",
         "This has already changed. Pull to refresh."),
        ("rawdea_cycle_too_soon",
         "A Project can start one new cycle every 30 days."),
        ("rawdea_cycle_unavailable",
         "Only a public, shipped Project can start its next cycle."),
        ("rawdea_cycle_undo_closed",
         "This cycle can't be undone now. Undo works for a day, before anything else is posted or anyone joins."),
        ("rawdea_filter_held:",
         "The opening note needs a check first. Remove links or reword it.")
    ]

    static func from(_ error: Error) -> String {
        let details = "\(error.localizedDescription) \(String(reflecting: error))"
            .lowercased()
        return messages.first { details.contains($0.marker) }?.text
            ?? PublicationErrorMessage.from(error)
    }
}
