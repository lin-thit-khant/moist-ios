//
//  SavedPostsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import SwiftUI

struct SavedPostsView: View {

    @StateObject private var viewModel =
        SavedPostsViewModel()

    var body: some View {

        List {

            // MARK: - Initial Loading

            if viewModel.isLoading &&
                viewModel.posts.isEmpty {

                HStack(spacing: 12) {

                    ProgressView()

                    Text("Loading saved posts...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowSeparator(.hidden)

            // MARK: - Initial Error

            } else if let error = viewModel.errorMessage,
                      viewModel.posts.isEmpty {

                VStack(spacing: 12) {

                    Image(
                        systemName: "exclamationmark.circle"
                    )
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                    Text("Couldn't load saved posts")
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

            // MARK: - Waiting for Initial Load

            } else if !viewModel.hasLoaded {

                ProgressView("Loading saved posts...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .listRowSeparator(.hidden)

            // MARK: - Empty State

            } else if viewModel.posts.isEmpty {

                ContentUnavailableView(
                    viewModel.hasBookmarks
                    ? "No Available Saved Posts"
                    : "Nothing Saved Yet",

                    systemImage: "bookmark",

                    description: Text(
                        viewModel.hasBookmarks
                        ? "Some saved posts may have become private or unavailable."
                        : "Open a post and tap Save to keep it for later."
                    )
                )
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)

            // MARK: - Saved Posts

            } else {

                ForEach(viewModel.posts) { post in

                    VStack(spacing: 0) {

                        PostRowView(post: post)

                        if viewModel.removingPostId == post.id {

                            ProgressView("Removing bookmark...")
                                .font(.caption)
                                .padding(.bottom, 8)
                        }

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
                    .listRowBackground(RawdeaPalette.canvas)

                    // Swipe left to remove the bookmark.

                    .swipeActions(edge: .trailing) {

                        Button(role: .destructive) {

                            Task {

                                await viewModel.removePost(
                                    postId: post.id
                                )
                            }

                        } label: {

                            Label(
                                "Unsave",
                                systemImage: "bookmark.slash"
                            )
                        }
                        .disabled(
                            viewModel.removingPostId != nil ||
                            viewModel.isLoading
                        )
                    }
                }

                // Keep existing rows visible
                // when a refresh fails.

                if let error = viewModel.errorMessage {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        Label(
                            "Couldn't refresh saved posts",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.subheadline)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Try Again") {

                            Task {
                                await viewModel.loadPosts()
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)

        // Refresh when this screen appears,
        // including after returning from
        // a discussion.

        .onAppear {

            Task {
                await viewModel.reloadVisiblePosts()
            }
        }

        .refreshable {

            await viewModel.loadPosts()
        }

        // MARK: - Removal Error

        .alert(
            "Couldn't remove bookmark",
            isPresented: Binding(
                get: {
                    viewModel.actionErrorMessage != nil
                },
                set: { isPresented in

                    if !isPresented {
                        viewModel.clearActionError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                viewModel.clearActionError()
            }

        } message: {

            Text(
                viewModel.actionErrorMessage ?? ""
            )
        }
    }
}
