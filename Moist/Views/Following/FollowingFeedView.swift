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

            // MARK: - Initial error

            if let error = viewModel.errorMessage,
               viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title:
                        "Couldn't load Following feed",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {
                        await viewModel.loadPosts()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            // MARK: - Initial loading

            } else if viewModel.posts.isEmpty &&
                        (
                            viewModel.isLoading ||
                            !viewModel.hasLoaded
                        ) {

                HStack(spacing: RawdeaSpacing.sm) {

                    ProgressView()

                    Text("Loading Following feed...")
                        .font(
                            RawdeaTypography.secondary
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, RawdeaSpacing.xl)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            // MARK: - Empty state

            } else if viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "person.2",
                    title:
                        viewModel.hasFollowedSources
                        ? "No Following Posts Yet"
                        : "Your Following Feed Is Empty",
                    message:
                        viewModel.hasFollowedSources
                        ? "People and Projects you follow have no visible posts yet."
                        : "Follow people or Projects to see their posts here."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            // MARK: - Posts

            } else {

                ForEach(viewModel.posts) { post in

                    VStack(spacing: 0) {

                        PostRowView(post: post)

                        Divider()
                            .overlay(
                                RawdeaPalette.divider
                            )
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

                    RawdeaInlineError(
                        message:
                            "Couldn't load more Following posts. \(error)"
                    )
                    .padding(.vertical, RawdeaSpacing.sm)
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
                }

                // MARK: - Load more

                if viewModel.hasMore {

                    HStack {

                        Spacer(minLength: 0)

                        if viewModel.isLoadingMore {

                            ProgressView("Loading more...")

                        } else {

                            Button("Load More") {

                                Task {

                                    await viewModel
                                        .loadMorePosts()
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
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
                }

                // MARK: - Refresh error

                if let error = viewModel.errorMessage {

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xs
                    ) {

                        RawdeaInlineError(
                            message:
                                "Couldn't refresh Following feed. \(error)"
                        )

                        Button("Try Again") {

                            Task {

                                await viewModel
                                    .refreshPosts()
                            }
                        }
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                    .padding(.vertical, RawdeaSpacing.sm)
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )

        // Preserve existing loading behavior.
        .onAppear {

            Task {

                await viewModel
                    .reloadVisiblePosts()
            }
        }

        .refreshable {

            await viewModel.refreshPosts()
        }
    }
}
