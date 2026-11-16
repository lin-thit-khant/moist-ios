//
//  FeedView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct FeedView: View {

    @ObservedObject var viewModel: FeedViewModel
    
    let currentUserId: UUID?
    
    @State private var selectedPostForEditing: Post?

    var body: some View {
        Group {

            if viewModel.isLoading && viewModel.posts.isEmpty {

                ProgressView("Loading posts...")

            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.posts.isEmpty {

                VStack(spacing: 12) {

                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Couldn't load posts")
                        .font(.headline)

                    Text(errorMessage)
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
                .padding()

            } else if viewModel.posts.isEmpty {

                VStack(spacing: 12) {

                    ContentUnavailableView(
                        "No Posts Yet",
                        systemImage: "text.bubble",
                        description: Text(
                            "Be the first to share something with Rawdea."
                        )
                    )

                    Button("Refresh") {
                        Task {
                            await viewModel.refreshPosts()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
            } else {

                List {

                    ForEach(viewModel.posts) { post in

                        VStack(spacing: 0) {

                            PostRowView(
                                post: post,
                                currentUserId: currentUserId,
                                onEdit: {
                                    selectedPostForEditing = post
                                },
                                onDelete: {
                                    Task {
                                        await viewModel.deletePost(
                                            postId: post.id
                                        )
                                    }
                                }
                            )

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
                    
                    
                    // MARK: - Load More Error

                    if let error = viewModel.paginationErrorMessage {

                        VStack(alignment: .leading, spacing: 8) {

                            Label(
                                "Couldn't load more posts",
                                systemImage: "exclamationmark.circle"
                            )
                            .font(.subheadline)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // MARK: - Refresh Error

                    if let error = viewModel.errorMessage {

                        VStack(alignment: .leading, spacing: 8) {

                            Text("Couldn't refresh posts")
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
                        .padding(.vertical, 8)
                    }

                    // MARK: - Load More

                    if viewModel.hasMore {

                        HStack {

                            Spacer()

                            if viewModel.isLoadingMore {

                                ProgressView("Loading more posts...")

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

                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.refreshPosts()
                }
            }
        }
        .task {
            await viewModel.loadPosts()
        }
        .sheet(item: $selectedPostForEditing) { post in
            EditPostView(
                post: post,
                viewModel: viewModel
            )
        }
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: {
                    viewModel.deletionErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearDeletionError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearDeletionError()
            }
        } message: {
            Text(viewModel.deletionErrorMessage ?? "")
        }
    }
}
