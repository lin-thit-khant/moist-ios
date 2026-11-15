//
//  UserFollowViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 15/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class UserFollowViewModel: ObservableObject {
    
    @Published private(set) var isFollowing = false
    @Published private(set) var isOwnProfile = false
    
    @Published private(set) var followerCount = 0
    @Published private(set) var followingCount = 0
    
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var hasLoaded = false
    
    @Published private(set) var errorMessage: String?
    
    private let followingService: FollowingService
    
    init(followingService: FollowingService = FollowingService()) {
        self.followingService = followingService
    }
    
    func load(userId: UUID) async {
        
        guard !isLoading && !isUpdating else {
            return
        }
        
        isLoading = true
        hasLoaded = false
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let viewerId = try await followingService.currentUserId()
            
            isOwnProfile = viewerId == userId
            
            followerCount = try await followingService
                .userFollowerCount(userId: userId)
            
            followingCount = try await followingService
                .userFollowingCount(userId: userId)
            
            if isOwnProfile {
                isFollowing = false
            } else {
                isFollowing = try await followingService
                    .isFollowingUser(userId: userId)
            }
            
            hasLoaded = true
            
        } catch is CancellationError {
            return
            
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleFollow(userId: UUID) async {
        
        guard hasLoaded,
              !isOwnProfile,
              !isLoading,
              !isUpdating else {
            return
        }
        
        isUpdating = true
        errorMessage = nil
        
        defer {
            isUpdating = false
        }
        
        do {
            if isFollowing {
                
                try await followingService.unfollowUser(
                    userId: userId
                )
                
                isFollowing = false
                followerCount = max(0, followerCount - 1)
                
            } else {
                
                try await followingService.followUser(
                    userId: userId
                )
                
                isFollowing = true
                followerCount += 1
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
