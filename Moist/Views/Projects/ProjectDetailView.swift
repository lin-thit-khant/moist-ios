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
    var onProjectChanged: () async -> Void = {}

    @StateObject private var viewModel =
        FeedViewModel()

    @StateObject private var followViewModel =
        ProjectFollowViewModel()

    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    @State private var currentUserId: UUID?
    @State private var ownerProfile: Profile?

    // Owner actions
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @State private var projectToRename: Project?

    @Environment(\.rawdeaCreatePostInProject) private var createPostInProject
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    private var isOwner: Bool {
        currentUserId == project.userId
    }

    var body: some View {

        projectPosts
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
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .topBarTrailing) {
                    ownerMenu
                }
            }
        }
        .sheet(item: $projectToRename) { project in
            ProjectRenameSheet(
                viewModel: projectsViewModel,
                project: project,
                onRenamed: onProjectChanged
            )
        }
        .alert(
            "Couldn't update Project",
            isPresented: Binding(
                get: {
                    projectToRename == nil &&
                    projectsViewModel.errorMessage != nil
                },
                set: { presented in
                    if !presented {
                        projectsViewModel.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                projectsViewModel.clearError()
            }
        } message: {
            Text(projectsViewModel.errorMessage ?? "")
        }

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

        // MARK: - Load owner

        .task(id: project.userId) {
            ownerProfile = try? await ProfileService()
                .fetchProfile(userId: project.userId)
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

    // MARK: - Owner menu

    private var ownerMenu: some View {
        Menu {
            Button {
                projectToRename = project
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
                runOwnerAction {
                    await projectsViewModel.setPinned(
                        projectId: project.id,
                        pinned: !project.isPinned
                    )
                }
            } label: {
                Label(
                    project.isPinned ? "Unpin" : "Pin",
                    systemImage: project.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                runOwnerAction {
                    await projectsViewModel.setHidden(
                        projectId: project.id,
                        hidden: !project.isHidden
                    )
                }
            } label: {
                Label(
                    project.isHidden ? "Make Public" : "Hide",
                    systemImage: project.isHidden ? "eye" : "eye.slash"
                )
            }

            Button {
                runOwnerAction {
                    await projectsViewModel.setArchived(
                        projectId: project.id,
                        archived: !project.isArchived
                    )
                }
            } label: {
                Label(
                    project.isArchived ? "Unarchive" : "Archive",
                    systemImage: "archivebox"
                )
            }
        } label: {
            if projectsViewModel.isUpdating {
                ProgressView()
            } else {
                Image(systemName: "ellipsis")
            }
        }
        .disabled(projectsViewModel.isUpdating)
        .accessibilityLabel("Project options")
    }

    private func runOwnerAction(
        _ action: @escaping () async -> Bool
    ) {
        Task {
            if await action() {
                await onProjectChanged()
            }
        }
    }

    // MARK: - Header

    private var ownerName: String? {
        guard let ownerProfile else { return nil }
        let name = ownerProfile.displayname.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? ownerProfile.username : name
    }

    private var followerCountText: String {
        let count = followViewModel.followerCount
        return count == 1 ? "1 follower" : "\(count.formatted()) followers"
    }

    private var projectHeader: some View {

        // Reads as part of the page rather than a card.
        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.xs
            ) {

                RawdeaProjectCard(
                    project: project,
                    showsOwnerStatus: isOwner
                )

                // Who the Project belongs to, linking to their profile.
                if !isOwner, let ownerName, let ownerProfile {

                    // A button, so the List row adds no chevron
                    // and only the name opens the profile.
                    Button {
                        openPostRoute?(.author(ownerProfile.id))
                    } label: {
                        HStack(spacing: RawdeaSpacing.xs) {
                            Text("by \(ownerName)")
                                .font(RawdeaTypography.secondary)
                                .foregroundStyle(RawdeaPalette.primaryText)
                                .lineLimit(2)
                        }
                        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("By \(ownerName)")
                    .accessibilityHint("Opens profile")
                }

                if followViewModel.isLoading &&
                   !followViewModel.hasLoaded {

                    RawdeaLoadingIndicator()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Loading Project details")

                } else if followViewModel.hasLoaded {

                    Label(followerCountText, systemImage: "person.2")
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)

                    if !followViewModel.isOwnProject &&
                       !project.isHidden &&
                       !project.isArchived {

                        RawdeaFollowButton(
                            isFollowing: followViewModel.isFollowing,
                            isUpdating: followViewModel.isUpdating,
                            followLabel: "Follow Project",
                            unfollowLabel: "Unfollow Project"
                        ) {
                            Task {
                                await followViewModel.toggleFollow(project: project)
                            }
                        }
                        .accessibilityIdentifier("project-follow-action")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(
            .horizontal,
            RawdeaSpacing.screenInset
        )
        .padding(
            .vertical,
            RawdeaSpacing.sm
        )
    }

    // MARK: - Project posts

    private var projectPosts: some View {

        List {

            // The header now scrolls with the
            // remaining Project content.

            VStack(spacing: 0) {

                projectHeader

                Divider()
                    .overlay(RawdeaPalette.divider)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(
                RawdeaPalette.canvas
            )

            // MARK: - Loading

            if viewModel.isLoading &&
               viewModel.posts.isEmpty {

                RawdeaLoadingIndicator("Loading posts...")
                    .frame(maxWidth: .infinity)
                    .padding(
                        .vertical,
                        RawdeaSpacing.xl
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

            // MARK: - Initial error

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
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            // MARK: - Empty Project

            } else if viewModel.posts.isEmpty {

                RawdeaEmptyState(
                    symbol: "text.bubble",
                    title: isOwner ? "An unfinished beginning" : "No posts yet",
                    message:
                        isOwner
                        ? "Write a post and choose this Project, or move an existing post here."
                        : "Posts shared in this Project will appear here.",
                    actionTitle: isOwner && createPostInProject != nil ? "Write a Post" : nil,
                    action: isOwner ? { createPostInProject?(project) } : nil
                )
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            // MARK: - Posts

            } else {

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
                            },
                            showsProjectLink: false
                        )

                        Divider()
                            .overlay(RawdeaPalette.divider)
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
