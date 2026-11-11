//
//  Post.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//

import Foundation

struct Post: Identifiable, Codable {
    
    let id: UUID
    let userId: UUID
    var content: String
    let createdAt: Date
    var author: PostAuthor?
    var projectId: UUID? = nil
    var project: PostProject? = nil
    var isHidden: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case author
        case projectId = "project_id"
        case project
        case isHidden = "is_hidden"
    }
}

struct PostAuthor: Codable {
    
    let id: UUID
    var displayName: String
    var username: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case username 
    }
}

struct PostProject:  Codable, Identifiable {
    let id: UUID
    let name: String
}
