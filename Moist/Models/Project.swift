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

struct ProjectStageEvent: Identifiable, Codable {
    let id: UUID
    let projectId: UUID
    let fromStage: ProjectStage
    let toStage: ProjectStage
    let postId: UUID?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
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
    }
}
