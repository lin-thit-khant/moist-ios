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
    
    // MARK: - Home Feed Pagination

    @Published private(set) var hasMore = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var paginationErrorMessage: String?

    private var nextPageCursor: RawdeaPageCursor?

    private let pagingService = FeedPagingService()
    
    @Published private(set) var deletingPostId: UUID?
    @Published private(set) var deletionErrorMessage: String?
    
    @Published private(set) var editingPostId: UUID?
    @Published private(set) var editErrorMessage: String?
    
    @Published private(set) var hidingPostId: UUID?
    @Published private(set) var visibilityErrorMessage: String?
    
    private let postService: PostService
    
    init(postService: PostService = PostService()) {
        self.postService = postService
    }
    
    
    // MARK: - Revalidate Feed Visibility

    func reloadVisiblePosts() async {

        guard !isLoading && !isLoadingMore else {
            return
        }

        // Remove potentially outdated content before
        // requesting the latest RLS-filtered posts.

        posts = []
        nextPageCursor = nil
        hasMore = false

        await loadPosts()
    }

    
    
    // MARK: - Load First Home Feed Page

    func loadPosts() async {

        guard !isLoading && !isLoadingMore else {
            return
        }

        isLoading = true
        errorMessage = nil
        paginationErrorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let page = try await pagingService
                .fetchAllPosts(before: nil)

            try Task.checkCancellation()

            // Replace the current feed with
            // the latest first page.

            posts = page.items
            nextPageCursor = page.nextCursor
            hasMore = page.hasMore

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            // Preserve existing posts when
            // refreshing fails.

            errorMessage = error.localizedDescription
        }
    }
    
    
    // MARK: - Load More Home Feed Posts

    func loadMorePosts() async {

        guard hasMore,
              !isLoading,
              !isLoadingMore,
              let cursor = nextPageCursor else {
            return
        }

        isLoadingMore = true
        paginationErrorMessage = nil

        defer {
            isLoadingMore = false
        }

        do {

            let page = try await pagingService
                .fetchAllPosts(before: cursor)

            try Task.checkCancellation()

            // Prevent duplicate IDs even if the
            // database changes between requests.

            let existingIDs = Set(
                posts.map(\.id)
            )

            let newPosts = page.items.filter {
                !existingIDs.contains($0.id)
            }

            posts.append(contentsOf: newPosts)

            nextPageCursor = page.nextCursor
            hasMore = page.hasMore

        } catch is CancellationError {
            return

        } catch {
            guard !Task.isCancelled else {
                return
            }

            // Existing pages remain available.

            paginationErrorMessage =
                error.localizedDescription
        }
    }


    
    func refreshPosts() async {
        await loadPosts()
    }
    
    func loadPosts(userId: UUID) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            posts = try await postService.fetchPosts(userId: userId)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
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
            try await postService.deletePost(postId: postId)
            
            posts.removeAll { $0.id == postId }
            
        } catch {
            deletionErrorMessage = error.localizedDescription
        }
    }
    
    func updatePost(postId: UUID, content: String) async -> Bool {
            
        guard editingPostId == nil,
              deletingPostId != postId else {
            return false
        }
        
        let trimmedContent = content.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        
        editErrorMessage = nil
        
        guard !trimmedContent.isEmpty else {
            editErrorMessage = "Post content cannot be empty."
            return false
        }
        
        guard trimmedContent.count <= 500 else {
            editErrorMessage = "Post cannot exceed 500 characters."
            return false
        }
        
        editingPostId = postId
        
        defer {
            editingPostId = nil
        }
        
        do {
            let updatedPost = try await postService.updatePost(
                postId: postId,
                content: trimmedContent
            )
            
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index] = updatedPost
            }
            
            return true
            
        } catch {
            editErrorMessage = error.localizedDescription
            return false
        }
    }
    
    func loadPosts(projectId: UUID) async {
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            posts = try await postService.fetchPosts(
                projectId: projectId
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
    
    func setPostHidden(
        postId: UUID,
        hidden: Bool
    ) async {
        
        guard hidingPostId == nil else { return }
        
        hidingPostId = postId
        visibilityErrorMessage = nil
        
        defer {
            hidingPostId = nil
        }
        
        do {
            try await postService.setPostHidden(
                postId: postId,
                hidden: hidden
            )
            
            if let index = posts.firstIndex(
                where: { $0.id == postId }
            ) {
                posts[index].isHidden = hidden
            }
            
        } catch {
            visibilityErrorMessage = error.localizedDescription
        }
    }
    
    func clearVisibilityError() {
        visibilityErrorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func clearDeletionError() {
        deletionErrorMessage = nil
    }
    
    func clearEditError() {
        editErrorMessage = nil
    }
}
