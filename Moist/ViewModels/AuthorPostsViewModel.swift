//
//  AuthorPostsViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class AuthorPostsViewModel: ObservableObject {
    
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let postService: PostService
    
    init(postService: PostService = PostService()) {
        self.postService = postService
    }
    
    func loadPosts(userId: UUID) async {
        
        isLoading = true
        errorMessage = nil
        posts = []
        
        defer {
            isLoading = false
        }
        
        do {
            posts = try await postService.fetchPosts(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
