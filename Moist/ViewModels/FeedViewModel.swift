//
//  FeedViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let postService: PostService
    
    init(postService: PostService = PostService()) {
        self.postService = postService
    }
    
    func loadPosts() async {
        
        guard !isLoading else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            posts = try await postService.fetchPosts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshPosts() async {
        await loadPosts()
    }
    
    func addPost(_ post: Post) {
        posts.removeAll { $0.id == post.id }
        posts.insert(post, at: 0)
    }
    
    func clearError() {
        errorMessage = nil
    }
}
