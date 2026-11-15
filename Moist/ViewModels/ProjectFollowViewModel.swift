//
//  ProjectFollowViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 15/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class ProjectFollowViewModel: ObservableObject {
    
    @Published private(set) var isFollowing = false
    @Published private(set) var isOwnProject = false
    
    @Published private(set) var followerCount = 0
    
    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false
    @Published private(set) var hasLoaded = false
    
    @Published private(set) var errorMessage: String?
    
    private let followingService: FollowingService
    
    init(followingService: FollowingService = FollowingService()) {
        self.followingService = followingService
    }
    
    func load(project: Project) async {
        
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
            
            isOwnProject = project.userId == viewerId
            
            followerCount = try await followingService
                .projectFollowerCount(projectId: project.id)
            
            if isOwnProject {
                isFollowing = false
            } else {
                isFollowing = try await followingService
                    .isFollowingProject(projectId: project.id)
            }
            
            hasLoaded = true
            
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleFollow(project: Project) async {
        
        guard hasLoaded,
              !isOwnProject,
              !project.isHidden,
              !project.isArchived,
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
                
                try await followingService.unfollowProject(
                    projectId: project.id
                )
                
                isFollowing = false
                followerCount = max(0, followerCount - 1)
            
            } else {
                
                try await followingService.followProject(
                    projectId: project.id
                )
                
                isFollowing = true
                followerCount += 1
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
