//
//  FollowingViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 15/11/2569 BE.
//

import Foundation
import Combine

@MainActor
final class FollowingViewModel: ObservableObject {
    
    @Published private(set) var followedPeople: [Profile] = []
    @Published private(set) var followedProjects: [Project] = []
    
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let followingService: FollowingService
    
    init(followingService: FollowingService = FollowingService()) {
        self.followingService = followingService
    }
    
    
    // MARK: - Revalidate Following List

    func reloadVisibleFollowing() async {

        guard !isLoading else {
            return
        }

        // Clear previously loaded relationships.

        followedPeople = []
        followedProjects = []

        await loadFollowing()
    }

    
    func loadFollowing() async {
        
        guard !isLoading else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let people = try await followingService
                .fetchFollowingPeople()
            
            let projects = try await followingService
                .fetchFollowingProjects()
            
            followedPeople = people
            followedProjects = projects
            
        } catch is CancellationError {
            return
            
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}
