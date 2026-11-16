//
//  DiscoveryCategory.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation

enum DiscoveryCategory: String, CaseIterable, Identifiable {

    case people
    case projects
    case posts

    var id: Self { self }

    var title: String {
        switch self {
        case .people:
            return "People"
        case .projects:
            return "Projects"
        case .posts:
            return "Posts"
        }
    }

    var systemImage: String {
        switch self {
        case .people:
            return "person.2"
        case .projects:
            return "folder"
        case .posts:
            return "text.bubble"
        }
    }
}
