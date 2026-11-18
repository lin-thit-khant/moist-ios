//
//  BlockedUser.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 17/11/2569 BE.
//

import Foundation

struct BlockedUser: Decodable, Identifiable {

    let blockedId: UUID
    let blockedUsername: String
    let blockedDisplayName: String
    let createdAt: Date

    var id: UUID {
        blockedId
    }

    var displayName: String {

        if blockedDisplayName.isEmpty {
            return blockedUsername
        }

        return blockedDisplayName
    }

    enum CodingKeys: String, CodingKey {

        case blockedId = "blocked_id"

        case blockedUsername = "blocked_username"

        case blockedDisplayName = "blocked_display_name"

        case createdAt = "created_at"
    }
}

