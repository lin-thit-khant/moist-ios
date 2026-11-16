//
//  FollowingFeedViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class FollowingFeedViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var posts: [Post] = []
    
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    
    @Published private(set) var hasFollowedSources = false
    
    @Published private(set) var errorMessage: String?
    
    // MARK: - Dependencies
    
    private let followingFeedService: FollowingFeedService
    
    init(
        followingFeedService: FollowingFeedService =
            FollowingFeedService()
    ) {
        self.followingFeedService = followingFeedService
    }
    
    // MARK: - Load Following Feed
    
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
            
            let snapshot = try await followingFeedService
                .fetchFeed()
            
            try Task.checkCancellation()
            
            posts = snapshot.posts
            
            hasFollowedSources = snapshot.hasFollowedSources
            
            hasLoaded = true
            
        } catch is CancellationError {
            return
            
        } catch {
            guard !Task.isCancelled else {
                return
            }
            
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Refresh
    
    func refreshPosts() async {
        await loadPosts()
    }
}
