//
//  FollowingFeedService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import Foundation

struct FollowingFeedSnapshot {
    
    let posts: [Post]
    let hasFollowedSources: Bool
}

struct FollowingFeedService {
    
    private let followingService: FollowingService
    private let postService: PostService
    
    init(
        followingService: FollowingService = FollowingService(),
        postService: PostService = PostService()
    ) {
        self.followingService = followingService
        self.postService = postService
    }
    
    // MARK: - Fetch Personalized Feed
    
    func fetchFeed() async throws -> FollowingFeedSnapshot {
        
        // 1. Find people followed by the current user.
        
        let followedPeople = try await followingService
            .fetchFollowingPeople()
        
        try Task.checkCancellation()
        
        // 2. Find followed, publicly accessible Projects.
        
        let followedProjects = try await followingService
            .fetchFollowingProjects()
        
        try Task.checkCancellation()
        
        let userIDs = followedPeople.map(\.id)
        let projectIDs = followedProjects.map(\.id)
        
        let hasFollowedSources = !userIDs.isEmpty || !projectIDs.isEmpty
        
        // 3. No follows means no personalized posts.
        
        guard hasFollowedSources else {
            return FollowingFeedSnapshot(
                posts: [],
                hasFollowedSources: false
            )
        }
        
        // 4. Fetch posts from followed people.
        
        let peoplePosts = try await postService
            .fetchcPosts(
                userIds: userIDs,
                maxPosts: 100
            )
        
        try Task.checkCancellation()
        
        // 5. Fetch posts from followed Projects.
        
        let projectPosts = try await postService
            .fetchPosts(
                projectIds: projectIDs,
                maxPosts: 100
            )
        
        try Task.checkCancellation()
        
        // 6. Deduplicate by post ID.
        //
        // A post might match both conditions:
        // - Its author is followed.
        // - Its Project is followed.
        //
        // It must appear only once.
        
        var uniquePosts: [UUID: Post] = [:]
        
        for post in peoplePosts {
            uniquePosts[post.id] = post
        }
        
        for post in projectPosts {
            uniquePosts[post.id] = post
        }
        
        // 7. Sort newest first.
        //
        // If timestamps match, use UUID to make
        // the ordering deterministic.
        
        let sortedPosts = uniquePosts.values.sorted {
            first, second in
            
            if first.createdAt == second.createdAt {
                return first.id.uuidString >
                second.id.uuidString
            }
            
            return first.createdAt > second.createdAt
        }
        
        // 8. Keep the newest 100 unique posts.
        
        let finalPosts = Array(
            sortedPosts.prefix(100)
        )
        
        return FollowingFeedSnapshot(
            posts: finalPosts,
            hasFollowedSources: true
        )
    }
}
