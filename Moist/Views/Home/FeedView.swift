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

            if viewModel.isLoading &&
               viewModel.posts.isEmpty {

                ProgressView("Loading posts...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            } else if let error = viewModel.errorMessage,
                      viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load posts",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {
                        await viewModel.loadPosts()
                    }
                }

            } else if viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "text.bubble",
                    title: "No posts yet",
                    message:
                        "Be the first to share something with Rawdea.",
                    actionTitle: "Refresh"
                ) {

                    Task {
                        await viewModel.refreshPosts()
                    }
                }

            } else {

                postsList
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )

        // Preserve the existing visibility
        // revalidation when returning to Home.
        .onAppear {

            Task {
                await viewModel.reloadVisiblePosts()
            }
        }

        // MARK: - Edit Post

        .sheet(item: $selectedPostForEditing) { post in

            EditPostView(
                post: post,
                viewModel: viewModel
            )
        }

        // MARK: - Delete error

        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: {
                    viewModel.deletionErrorMessage != nil
                },
                set: { presented in

                    if !presented {
                        viewModel.clearDeletionError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                viewModel.clearDeletionError()
            }

        } message: {

            Text(
                viewModel.deletionErrorMessage ?? ""
            )
        }
    }

    // MARK: - Continuous Reading First feed

    private var postsList: some View {

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
                        .overlay(RawdeaPalette.divider)
                        .padding(.horizontal)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }

            // MARK: - Pagination error

            if let error =
                viewModel.paginationErrorMessage {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInlineError(
                        message:
                            "Couldn't load more posts. \(error)"
                    )
                }
                .padding(.vertical, RawdeaSpacing.sm)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
            }

            // MARK: - Refresh error

            if let error = viewModel.errorMessage {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInlineError(
                        message:
                            "Couldn't refresh posts. \(error)"
                    )

                    Button("Try Again") {

                        Task {
                            await viewModel.refreshPosts()
                        }
                    }
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
                .padding(.vertical, RawdeaSpacing.sm)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
            }

            // MARK: - Load more

            if viewModel.hasMore {

                HStack {

                    Spacer(minLength: 0)

                    if viewModel.isLoadingMore {

                        ProgressView(
                            "Loading more posts..."
                        )

                    } else {

                        Button("Load More") {

                            Task {
                                await viewModel.loadMorePosts()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, RawdeaSpacing.sm)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .refreshable {

            await viewModel.refreshPosts()
        }
    }
}
