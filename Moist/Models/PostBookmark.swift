//
//  PostBookmark.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation

struct PostBookmark: Decodable {

    let postId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
    }
}
