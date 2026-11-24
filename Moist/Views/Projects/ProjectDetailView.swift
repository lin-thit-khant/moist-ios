//
//  ProjectDetailView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//


import SwiftUI
import Supabase

struct ProjectDetailView: View {

    let project: Project
    let projects: [Project]

    @StateObject private var viewModel =
        FeedViewModel()

    @StateObject private var followViewModel =
        ProjectFollowViewModel()

    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    @State private var currentUserId: UUID?

    private var isOwner: Bool {
        currentUserId == project.userId
    }

    var body: some View {

        VStack(spacing: 0) {

            projectHeader

            Divider()
                .overlay(RawdeaPalette.divider)

            projectPosts
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Load posts

        .task(id: project.id) {

            await viewModel.loadPosts(
                projectId: project.id
            )
        }

        // MARK: - Load follow state

        .task(id: project.id) {

            await followViewModel.load(
                project: project
            )
        }

        // MARK: - Identify viewer

        .task {

            if let user = try? await SupabaseManager
                .client.auth.session.user {

                currentUserId = user.id
            }
        }

        // MARK: - Edit

        .sheet(item: $selectedPostForEditing) { post in

            EditPostView(
                post: post,
                viewModel: viewModel
            )
        }

        // MARK: - Move

        .sheet(item: $selectedPostForMoving) { post in

            MovePostToProjectView(
                post: post,
                projects: projects,
                onMoved: {

                    await viewModel.loadPosts(
                        projectId: project.id
                    )
                }
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

        // MARK: - Visibility error

        .alert(
            "Couldn't change post visibility",
            isPresented: Binding(
                get: {
                    viewModel.visibilityErrorMessage != nil
                },
                set: { presented in

                    if !presented {
                        viewModel.clearVisibilityError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {

                viewModel.clearVisibilityError()
            }

        } message: {

            Text(
                viewModel.visibilityErrorMessage ?? ""
            )
        }
    }

    // MARK: - Header

    private var projectHeader: some View {

        RawdeaProjectSurface {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.md
            ) {

                RawdeaProjectCard(
                    project: project,
                    showsOwnerStatus: isOwner
                )

                if followViewModel.isLoading &&
                   !followViewModel.hasLoaded {

                    ProgressView(
                        "Loading Project details..."
                    )

                } else if followViewModel.hasLoaded {

                    HStack(
                        spacing: RawdeaSpacing.sm
                    ) {

                        Label(
                            "\(followViewModel.followerCount) followers",
                            systemImage: "person.2"
                        )
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )

                        Spacer(minLength: 0)

                        if !followViewModel.isOwnProject &&
                           !project.isHidden &&
                           !project.isArchived {

                            Button {

                                Task {

                                    await followViewModel
                                        .toggleFollow(
                                            project: project
                                        )
                                }

                            } label: {

                                HStack(
                                    spacing: RawdeaSpacing.xs
                                ) {

                                    if followViewModel.isUpdating {

                                        ProgressView()
                                            .accessibilityHidden(true)
                                    }

                                    Text(
                                        followViewModel.isFollowing
                                        ? "Following"
                                        : "Follow"
                                    )
                                    .font(
                                        RawdeaTypography.authorName
                                    )
                                }
                                .frame(
                                    minHeight:
                                        RawdeaSpacing.minimumTouchTarget
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(RawdeaPalette.accent)
                            .disabled(
                                followViewModel.isUpdating
                            )
                            .accessibilityLabel(
                                followViewModel.isFollowing
                                ? "Unfollow Project"
                                : "Follow Project"
                            )
                        }
                    }
                }

                if let error =
                    followViewModel.errorMessage {

                    RawdeaInlineError(
                        message: error
                    )

                    if !followViewModel.hasLoaded {

                        Button(
                            "Retry Follow Status"
                        ) {

                            Task {

                                await followViewModel.load(
                                    project: project
                                )
                            }
                        }
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                }
            }
        }
        .padding(
            .horizontal,
            RawdeaSpacing.screenInset
        )
        .padding(
            .vertical,
            RawdeaSpacing.md
        )
    }

    // MARK: - Project posts

    @ViewBuilder
    private var projectPosts: some View {

        if viewModel.isLoading &&
           viewModel.posts.isEmpty {

            ProgressView("Loading posts...")
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

        } else if let error =
            viewModel.errorMessage,
            viewModel.posts.isEmpty {

            RawdeaEmptyState(
                symbol: "exclamationmark.circle",
                title: "Couldn't load posts",
                message: error,
                actionTitle: "Try Again"
            ) {

                Task {

                    await viewModel.loadPosts(
                        projectId: project.id
                    )
                }
            }

        } else if viewModel.posts.isEmpty {

            RawdeaEmptyState(
                symbol: "text.bubble",
                title: "An unfinished beginning",
                message:
                    isOwner
                    ? "Move a thought here whenever you're ready."
                    : "No public posts are available in this Project yet."
            )

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
                            },
                            onMove: {

                                selectedPostForMoving = post
                            },
                            onHide: {

                                Task {

                                    await viewModel.setPostHidden(
                                        postId: post.id,
                                        hidden: !post.isHidden
                                    )
                                }
                            }
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
                }

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

                                await viewModel.loadPosts(
                                    projectId: project.id
                                )
                            }
                        }
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(RawdeaPalette.canvas)
            .refreshable {

                await viewModel.loadPosts(
                    projectId: project.id
                )
            }
        }
    }
}
