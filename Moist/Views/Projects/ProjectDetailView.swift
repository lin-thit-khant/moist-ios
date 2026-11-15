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

    @StateObject private var viewModel = FeedViewModel()

    @StateObject private var followViewModel =
        ProjectFollowViewModel()

    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    @State private var currentUserId: UUID?

    var body: some View {

        VStack(spacing: 0) {

            // New Project follow header

            projectFollowHeader

            Divider()

            // Existing Project posts

            Group {

                if viewModel.isLoading && viewModel.posts.isEmpty {

                    ProgressView("Loading projects...")

                } else if let error = viewModel.errorMessage,
                          viewModel.posts.isEmpty {

                    VStack(spacing: 12) {

                        Text("Couldn't load posts")
                            .font(.headline)

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Try Again") {
                            Task {
                                await viewModel.loadPosts(
                                    projectId: project.id
                                )
                            }
                        }
                    }
                    .padding()

                } else if viewModel.posts.isEmpty {

                    ContentUnavailableView(
                        "An unfinished beginning",
                        systemImage: "text.bubble",
                        description: Text(
                            "Move a thought here whenever you're ready."
                        )
                    )

                } else {

                    List {

                        ForEach(viewModel.posts) { post in

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
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await viewModel.loadPosts(
                            projectId: project.id
                        )
                    }
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)

        // Existing Project post loading

        .task(id: project.id) {
            await viewModel.loadPosts(
                projectId: project.id
            )
        }

        // New Project follow loading

        .task(id: project.id) {
            await followViewModel.load(
                project: project
            )
        }

        // Existing authenticated user lookup

        .task {
            if let user = try? await SupabaseManager
                .client.auth.session.user {

                currentUserId = user.id
            }
        }

        // Existing edit sheet

        .sheet(item: $selectedPostForEditing) { post in

            EditPostView(
                post: post,
                viewModel: viewModel
            )
        }

        // Existing move sheet

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

        // Existing deletion alert

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

        // Existing visibility alert

        .alert(
            "Couldn't change post visibility",
            isPresented: Binding(
                get: {
                    viewModel.visibilityErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        viewModel.clearVisibilityError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                viewModel.clearVisibilityError()
            }

        } message: {

            Text(viewModel.visibilityErrorMessage ?? "")
        }
    }

    // MARK: - Project Follow Header

    private var projectFollowHeader: some View {

        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Text(project.name)
                        .font(.headline)

                    if followViewModel.hasLoaded {

                        Text(
                            "\(followViewModel.followerCount) followers"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if followViewModel.isLoading {

                    ProgressView()

                } else if followViewModel.hasLoaded &&
                          !followViewModel.isOwnProject &&
                          !project.isHidden &&
                          !project.isArchived {

                    Button {

                        Task {
                            await followViewModel.toggleFollow(
                                project: project
                            )
                        }

                    } label: {

                        HStack(spacing: 6) {

                            if followViewModel.isUpdating {
                                ProgressView()
                            }

                            Text(
                                followViewModel.isFollowing
                                ? "Following"
                                : "Follow"
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(followViewModel.isUpdating)
                }
            }

            if let error = followViewModel.errorMessage {

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)

                if !followViewModel.hasLoaded {

                    Button("Retry Follow Status") {
                        Task {
                            await followViewModel.load(
                                project: project
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

