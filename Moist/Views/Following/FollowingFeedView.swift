//
//  FollowingFeedView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import SwiftUI

struct FollowingFeedView: View {
    
    @ObservedObject var viewModel: FollowingFeedViewModel
    
    var body: some View {
        
        List {
            
            // MARK: - Error Before First Successful Load
            
            if let error = viewModel.errorMessage,
               viewModel.posts.isEmpty {
                
                VStack(spacing: 12) {
                    
                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Couldn't load Following feed")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.loadPosts()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowSeparator(.hidden)
                
                // MARK: - Initial Loading
            } else if viewModel.posts.isEmpty &&
                        (
                            viewModel.isLoading ||
                            !viewModel.hasLoaded
                        ) {
                
                HStack(spacing: 12) {
                    
                    ProgressView()
                    
                    Text("Loading Following feed...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowSeparator(.hidden)
                
                // MARK: - Empty State
                
            } else if viewModel.posts.isEmpty {
                
                ContentUnavailableView(
                    viewModel.hasFollowedSources
                    ? "No Following Posts Yet"
                    : "Your Following Feed Is Empty",
                    
                    systemImage: "person.2",
                    
                    description: Text(
                        viewModel.hasFollowedSources
                        ? "People and Projects you follow have no visible posts yet."
                        : "Follow people or Projects to see their posts here."
                    )
                )
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                
                // MARK: - Feed Content
            } else {
                
                ForEach(viewModel.posts) { post in
                    
                    VStack(spacing: 0) {
                        
                        PostRowView(post: post)
                        
                        Divider()
                            .padding(.horizontal)
                    }
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: 0,
                            bottom: 0,
                            trailing: 0
                        )
                    )
                    .listRowSeparator(.hidden)
                }
                
                
                // MARK: - Pagination Error

                if let error = viewModel.paginationErrorMessage {

                    VStack(alignment: .leading, spacing: 8) {

                        Label(
                            "Couldn't load more Following posts",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.subheadline)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Load More

                if viewModel.hasMore {

                    HStack {

                        Spacer()

                        if viewModel.isLoadingMore {

                            ProgressView("Loading more...")

                        } else {

                            Button("Load More") {

                                Task {
                                    await viewModel.loadMorePosts()
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .listRowSeparator(.hidden)
                }

                
                // Keep existing posts visible if
                // refreshing fails.
                
                if let error = viewModel.errorMessage {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        
                        Label(
                            "Couldn't refresh Following feed",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.subheadline)
                        .fontWeight(.medium)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.refreshPosts()
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .listStyle(.plain)
        
        // Pull to refresh works even with
        // an empty feed.
        
        .refreshable {
            await viewModel.refreshPosts()
        }
        
        // Load whenever this view enters
        // the Home feed hierarchy.
        
        .task {
            await viewModel.loadPosts()
        }
    }
}
