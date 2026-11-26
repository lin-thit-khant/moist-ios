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

    @Environment(\.rawdeaOpenExplore) private var openExplore

    @Environment(\.scenePhase)
    private var scenePhase

    var body: some View {

        List {

            if let error = viewModel.errorMessage,
               viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load saved posts",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {

                        await viewModel.loadPosts()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else if !viewModel.hasLoaded ||
                      (
                        viewModel.isLoading &&
                        viewModel.posts.isEmpty
                      ) {

                RawdeaLoadingIndicator("Loading saved posts...")
                    .frame(maxWidth: .infinity)
                    .padding(
                        .vertical,
                        RawdeaSpacing.xl
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

            } else if viewModel.posts.isEmpty {

                emptyState

            } else {

                ForEach(viewModel.posts) { post in

                    savedPostRow(post)
                }

                if let error = viewModel.errorMessage {

                    refreshError(error)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Saved Posts")
        .navigationBarTitleDisplayMode(.inline)

        // Revalidate after returning from
        // Discussion or another child screen.

        .onAppear {

            Task {

                await viewModel.reloadVisiblePosts()
            }
        }

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {

                await viewModel.reloadVisiblePosts()
            }
        }

        .rawdeaRefreshable {

            await viewModel.loadPosts()
        }

        .alert(
            "Couldn't remove bookmark",
            isPresented: Binding(
                get: {

                    viewModel.actionErrorMessage != nil
                },
                set: { presented in

                    if !presented {

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

    // MARK: - Saved post row

    private func savedPostRow(
        _ post: Post
    ) -> some View {

        VStack(spacing: 0) {

            PostRowView(
                post: post,
                onUnsave: {

                    Task {

                        await viewModel.removePost(
                            postId: post.id
                        )
                    }
                },
                isUnsaveDisabled:
                    viewModel.isBusy,
                isUnsaving:
                    viewModel.removingPostId ==
                    post.id
            )

            Divider()
                .overlay(
                    RawdeaPalette.divider
                )
                .padding(
                    .horizontal,
                    RawdeaSpacing.screenInset
                )
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(
            RawdeaPalette.canvas
        )

        // Both the inline button and swipe action
        // use the same removePost method.

        .swipeActions(
            edge: .trailing,
            allowsFullSwipe: false
        ) {

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
            .disabled(viewModel.isBusy)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {

        RawdeaEmptyState(
            symbol: "bookmark",
            title:
                viewModel.hasBookmarks
                ? "No available saved posts"
                : "Nothing saved yet",
            message:
                viewModel.hasBookmarks
                ? "Your saved posts may have become private or unavailable."
                : "Save a post to come back to it whenever you want.",
            actionTitle:
                !viewModel.hasBookmarks && openExplore != nil
                ? "Explore"
                : nil,
            action:
                viewModel.hasBookmarks ? nil : openExplore
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RawdeaPalette.canvas
        )
    }

    // MARK: - Refresh error

    private func refreshError(
        _ error: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            RawdeaInlineError(
                message:
                    "Couldn't refresh saved posts. \(error)"
            )

            Button("Try Again") {

                Task {

                    await viewModel.loadPosts()
                }
            }
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
        }
        .padding(
            .vertical,
            RawdeaSpacing.sm
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RawdeaPalette.canvas
        )
    }
}
