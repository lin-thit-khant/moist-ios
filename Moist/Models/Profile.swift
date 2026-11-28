//
//  Profile.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import Foundation

struct Profile: Codable, Identifiable {
    
    let id: UUID
    var username: String
    var displayname: String
    var bio: String
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayname = "display_name"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension Profile {

    /// Matches the `profiles_username_check` database constraint.
    static func isValidUsername(_ username: String) -> Bool {
        username.range(of: "^[a-z0-9_]{3,24}$", options: .regularExpression) != nil
    }
}
