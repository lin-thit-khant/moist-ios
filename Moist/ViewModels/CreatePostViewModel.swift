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
    
    /// The post was published, but its Project's stage was not moved.
    @Published private(set) var stageChangeFailed = false
    
    private let postService: PostService
    private let projectService: ProjectService
    
    init(
        postService: PostService = PostService(),
        projectService: ProjectService = ProjectService()
    ) {
        self.postService = postService
        self.projectService = projectService
    }
    
    func publish(
        content: String,
        projectId: UUID? = nil,
        kind: PostKind = .note,
        newStage: ProjectStage? = nil
    ) async -> Bool {
        guard !isPublishing else { return false }
        
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        guard !trimmedContent.isEmpty else {
            errorMessage = "Write something before publishing"
            return false
        }
        
        guard RawdeaTextLength.count(trimmedContent) <=
                RawdeaPostDraft.characterLimit else {

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
                content: trimmedContent,
                projectId: projectId,
                kind: kind
            )
            publishedPost = post
            
            // The post is already public here, so a failed
            // stage move must not be reported as a failed post.
            if let newStage, let projectId {
                do {
                    _ = try await projectService.setStage(
                        projectId: projectId,
                        stage: newStage,
                        postId: post.id
                    )
                } catch {
                    stageChangeFailed = true
                }
            }
            
            return true
        } catch {
            errorMessage = PublicationErrorMessage.from(error)
            
            return false
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
