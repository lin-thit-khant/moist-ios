//
//  Project.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//

import Foundation

enum ProjectStage: String, Codable, CaseIterable {
    case early
    case inProgress = "in_progress"
    case shipped
    
    var title: String {
        switch self {
        case .early: "Early"
        case .inProgress: "In progress"
        case .shipped: "Shipped"
        }
    }
}

/// Someone named for work in a stage.
struct StageCredit: Codable {
    let userId: UUID
    var person: Person? = nil

    struct Person: Codable {
        let username: String
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case person
    }
}

struct ProjectStageEvent: Identifiable, Codable {
    let id: UUID
    let projectId: UUID
    let fromStage: ProjectStage
    let toStage: ProjectStage
    let postId: UUID?
    let createdAt: Date
    var credits: [StageCredit]? = nil
    
    var creditNames: [String] {
        (credits ?? []).compactMap(\.person?.username).sorted()
    }
    
    /// "Moved to In progress · with maya and ravi".
    var marker: String {
        let move = "Moved to \(toStage.title)"
        let names = creditNames
        return names.isEmpty
            ? move
            : "\(move) · with \(CreditNames.sentence(names))"
    }
    
    enum CodingKeys: String, CodingKey {
        case credits
        case id
        case projectId = "project_id"
        case fromStage = "from_stage"
        case toStage = "to_stage"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}

struct Project: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    var name: String
    let createdAt: Date
    var isArchived: Bool
    var isHidden: Bool
    var isPinned: Bool
    var stage: ProjectStage
    var stageChangedAt: Date
    let isDefault: Bool
    var about: String = ""
    var suggestionsEnabled: Bool? = nil
    
    /// Contributors pause at Shipped and while out of sight.
    var takesContributions: Bool {
        !isDefault && !isHidden && !isArchived && stage != .shipped
    }
    
    /// The server decides who may suggest. This hides the button
    /// when nobody can.
    var takesSuggestions: Bool {
        (suggestionsEnabled ?? true) &&
        !isDefault && !isHidden && !isArchived && stage != .shipped
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case createdAt = "created_at"
        case isArchived = "is_archived"
        case isHidden = "is_hidden"
        case isPinned = "is_pinned"
        case stage
        case stageChangedAt = "stage_changed_at"
        case isDefault = "is_default"
        case about = "description"
        case suggestionsEnabled = "suggestions_enabled"
    }
}
