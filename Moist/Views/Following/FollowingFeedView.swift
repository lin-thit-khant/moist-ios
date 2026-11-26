//
//  FollowingFeedView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import SwiftUI

struct FollowingFeedView: View {

    @ObservedObject var viewModel: FollowingFeedViewModel
    let onExplore: () -> Void

    var body: some View {
        RawdeaHomeFeedList(
            posts: viewModel.posts,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            hasLoadError: viewModel.errorMessage != nil,
            hasMore: viewModel.hasMore,
            isLoadingMore: viewModel.isLoadingMore,
            hasPaginationError: viewModel.paginationErrorMessage != nil,
            emptySymbol: "person.2",
            emptyTitle: viewModel.hasFollowedSources ? "No posts from your follows yet" : "Your Following feed is empty",
            emptyMessage: viewModel.hasFollowedSources
                ? "Explore more people and projects to follow."
                : "Follow people or projects to see their posts here.",
            emptyActionTitle: "Explore",
            emptyAction: onExplore,
            refresh: viewModel.refreshPosts,
            loadMore: viewModel.loadMorePosts
        ) { post in
            PostRowView(
                post: post,
                isReader: true
            )
        }
        .onAppear {
            Task { await viewModel.reloadVisiblePosts() }
        }
    }
}
