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
    
    @Published private(set) var deletingPostId: UUID?
    @Published private(set) var deletionErrorMessage: String?
    
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
    
    func deletePost(postId: UUID) async {
        
        guard deletingPostId == nil else {
            return
        }
        
        deletingPostId = postId
        deletionErrorMessage = nil
        
        defer {
            deletingPostId = nil
        }
        
        do {
            try await postService.deletePosts(postId: postId)
            
            posts.removeAll { $0.id == postId }
            
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearDeletionError() {
        deletionErrorMessage = nil
    }
}
