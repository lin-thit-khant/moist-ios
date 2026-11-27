//
//  PostComment.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import Foundation

struct PostComment: Identifiable, Decodable {

    let id: UUID
    let postId: UUID
    let userId: UUID

    var content: String

    let createdAt: Date

    var author: PostAuthor?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case author
    }
}

/// A person's comment, with the post it answers.
struct ProfileReply: Identifiable, Decodable {

    struct Original: Decodable {
        let content: String
    }

    let id: UUID
    let postId: UUID
    let content: String
    let createdAt: Date
    let post: Original

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case content
        case createdAt = "created_at"
        case post
    }
}
