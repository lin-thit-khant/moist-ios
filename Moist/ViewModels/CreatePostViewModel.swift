//
//  CreatePostViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class CreatePostViewModel: ObservableObject {
    
    @Published private(set) var isPublishing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var publishedPost: Post?
    
    private let postService: PostService
    
    init(postService: PostService = PostService()) {
        self.postService = postService
    }
    
    func publish(content: String) async -> Bool {
        guard !isPublishing else { return false }
        
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmedContent.isEmpty else {
            errorMessage = "Write something before publishing"
            return false
        }
        
        guard trimmedContent.count <= 500 else {
            errorMessage = "Posts can be up to 500 characters."
            return false
        }
        
        isPublishing = true
        errorMessage = nil
        publishedPost = nil
        
        defer {
            isPublishing = false
        }
        
        do {
            let post = try await postService.createPost(
                content: trimmedContent
            )
            publishedPost = post
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
