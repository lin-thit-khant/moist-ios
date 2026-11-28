//
//  ProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import SwiftUI

struct ProfileView: View {
    
    var isSelected: Bool = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.rawdeaCreatePost) private var createPost

    @State private var isProfileContentVisible = false

    @State private var isRefreshingProfileContent = false

    @State private var needsProfileContentRefresh = false
    
    @StateObject private var viewModel = ProfileViewModel()
        
    @State private var isAccountSuspended = false
    
    @StateObject private var postsViewModel = FeedViewModel()
    
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @StateObject private var followViewModel = UserFollowViewModel()
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    
    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    
    private var sortedActiveProjects: [Project] {
        projectsViewModel.projects
            .filter { !$0.isArchived }
            .sorted { first, second in
                
                if first.isPinned != second.isPinned {
                    return first.isPinned
                }
                
                return first.createdAt > second.createdAt
            }
    }
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.profile == nil {
                RawdeaLoadingIndicator("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.profile == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    
                    Text("Couldn't load your profile")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.loadProfile()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let profile = viewModel.profile {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        ProfileContentView(profile: profile)
                        
                        
                        // MARK: - Account Moderation Notice

                        if isAccountSuspended {

                            VStack(alignment: .leading, spacing: 10) {

                                Label(
                                    "Account Suspended",
                                    systemImage: "exclamationmark.shield.fill"
                                )
                                .font(.headline)

                                Text(
                                    """
                                    Your account has been restricted following a moderation review.

                                    Your public content is currently unavailable to other users. Publishing, commenting, liking, and following are restricted.

                                    You can still sign in and view your own profile.
                                    """
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                
                                
                                NavigationLink {

                                    SafetyCenterView(initialKind: .appeal)

                                } label: {

                                    Label(
                                        "Appeal This Decision",
                                        systemImage: "envelope.open"
                                    )
                                }
                                .buttonStyle(.bordered)

                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding()
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                        }

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        
                        if followViewModel.hasLoaded {
                            followCounts
                        }

                        profileActions(profile)

                        RawdeaProfileWorkSections(
                            userId: profile.id,
                            chips: { projectChips },
                            posts: { postsSection(profile: profile) }
                        )
                    }
                    .padding(
                        .horizontal,
                        RawdeaSpacing.screenInset
                    )
                    .padding(
                        .vertical,
                        RawdeaSpacing.lg
                    )
                }
                
                .onAppear {

                    isProfileContentVisible = true

                    guard isSelected else {
                        return
                    }

                    Task {

                        await refreshProfileContent(
                            userId: profile.id
                        )
                    }
                }
                .onDisappear {

                    isProfileContentVisible = false
                }
                .onChange(of: isSelected) { _, selected in

                    guard selected,
                          isProfileContentVisible else {

                        return
                    }

                    Task {

                        await refreshProfileContent(
                            userId: profile.id
                        )
                    }
                }
                .rawdeaRefreshable {

                    await viewModel.loadProfile()

                    isAccountSuspended = (
                        try? await ModerationService()
                            .isMyAccountSuspended()
                    ) ?? false

                    guard let currentProfile =
                        viewModel.profile else {

                        return
                    }

                    await refreshProfileContent(
                        userId: currentProfile.id
                    )
                }

            } else {
                RawdeaLoadingIndicator("Preparing profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // If an earlier load was cancelled (for example
                    // when sign-in or an appearance change rebuilt
                    // the screen), start it again. The load runs in
                    // its own Task so this spinner disappearing
                    // cannot cancel it.
                    .onAppear {
                        guard viewModel.profile == nil,
                              viewModel.errorMessage == nil,
                              !viewModel.isLoading else {
                            return
                        }
                        Task {
                            await viewModel.loadProfile()
                        }
                    }
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Menu {

                    Button("Saved posts", systemImage: "bookmark") {
                        openPostRoute?(.savedPosts)
                    }

                    Button("Following", systemImage: "person.2") {
                        openPostRoute?(.following)
                    }

                    Button("Settings", systemImage: "gearshape") {
                        openPostRoute?(.settings)
                    }

                } label: {

                    Image(systemName: "line.3.horizontal")
                        .frame(
                            width:
                                RawdeaSpacing.minimumTouchTarget,
                            height:
                                RawdeaSpacing.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Menu")
            }
        }

        .task {
            await viewModel.loadProfile()
        }
        
        .task(id: viewModel.profile?.id) {

            guard viewModel.profile != nil else {
                isAccountSuspended = false
                return
            }

            do {

                isAccountSuspended = try await ModerationService()
                    .isMyAccountSuspended()

            } catch {

                isAccountSuspended = false
            }
        }

        .sheet(item: $selectedPostForEditing) { post in
            EditPostView(
                post: post,
                viewModel: postsViewModel
            )
        }
        .sheet(item: $selectedPostForMoving, content: { post in
            MovePostToProjectView(
                post: post,
                projects: projectsViewModel.projects,
                onMoved: {
                    if let userId = viewModel.profile?.id {
                        await postsViewModel.loadPosts(
                            userId: userId
                        )
                    }
                }
            )
        })
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: {
                    postsViewModel.deletionErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        postsViewModel.clearDeletionError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                postsViewModel.clearDeletionError()
            }
        } message: {
            Text(postsViewModel.deletionErrorMessage ?? "")
        }
        .alert(
            "Couldn't change post visibility",
            isPresented: Binding(
                get: {
                    postsViewModel.visibilityErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        postsViewModel.clearVisibilityError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                postsViewModel.clearVisibilityError()
            }
        } message: {
            Text(postsViewModel.visibilityErrorMessage ?? "")
        }
    }
    
    // MARK: - Refresh Profile Content

    @MainActor
    private func refreshProfileContent(
        userId: UUID
    ) async {

        guard viewModel.profile?.id == userId else {
            return
        }

        await followViewModel.load(userId: userId)

        // If another refresh is already running,
        // request one more pass instead of
        // starting competing requests.

        if isRefreshingProfileContent {

            needsProfileContentRefresh = true

            return
        }

        isRefreshingProfileContent = true

        defer {

            isRefreshingProfileContent = false
            needsProfileContentRefresh = false
        }

        repeat {

            needsProfileContentRefresh = false

            guard !Task.isCancelled,
                  viewModel.profile?.id == userId else {

                return
            }

            await postsViewModel.loadPosts(
                userId: userId
            )

            guard !Task.isCancelled else {
                return
            }

            await projectsViewModel.loadProjects(
                userId: userId
            )

        } while needsProfileContentRefresh &&
                !Task.isCancelled
    }

    private func postsSection(profile: Profile) -> some View {
        let posts = postsViewModel.posts

        return VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {
            if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                RawdeaLoadingIndicator("Loading posts...")
            } else if let errorMessage = postsViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await postsViewModel.loadPosts(userId: profile.id) }
                } label: {
                    Text("Try Again")
                        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
            } else if posts.isEmpty {
                Text("Posts you share appear here.")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let createPost {
                    Button(action: createPost) {
                        Label("Write a Post", systemImage: "square.and.pencil")
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.primaryText)
                            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(posts) { post in
                        PostRowView(
                            post: post,
                            currentUserId: profile.id,
                            onEdit: { selectedPostForEditing = post },
                            onDelete: {
                                Task { await postsViewModel.deletePost(postId: post.id) }
                            },
                            onMove: { selectedPostForMoving = post },
                            onHide: {
                                Task {
                                    await postsViewModel.setPostHidden(
                                        postId: post.id,
                                        hidden: !post.isHidden
                                    )
                                }
                            },
                            horizontalInset: 0
                        )

                        Divider()
                            .overlay(RawdeaPalette.divider)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Follow counts

    private var followCounts: some View {

        let followers = followViewModel.followerCount
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.md))

        return layout {
            followCount(
                followers,
                followers == 1 ? "follower" : "followers",
                route: .followers,
                hint: "Opens people who follow you"
            )
            followCount(
                followViewModel.followingCount,
                "following",
                route: .following,
                hint: "Opens people and Projects you follow"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func followCount(
        _ count: Int,
        _ label: String,
        route: RawdeaPostRoute,
        hint: String
    ) -> some View {

        Button {
            openPostRoute?(route)
        } label: {
            Text("\(Text(count.formatted()).fontWeight(.semibold).foregroundStyle(RawdeaPalette.primaryText)) \(label)")
                .font(RawdeaTypography.secondary)
                .foregroundStyle(RawdeaPalette.secondaryText)
                .frame(minWidth: RawdeaSpacing.minimumTouchTarget, minHeight: RawdeaSpacing.minimumTouchTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    // MARK: - Profile actions

    private func profileActions(_ profile: Profile) -> some View {
        NavigationLink {
            EditProfileView(
                viewModel: viewModel,
                profile: profile
            )
        } label: {
            RawdeaOutlinePillLabel(title: "Edit profile")
        }
        .buttonStyle(.plain)
    }

    // MARK: - Projects

    // Rename, pin, hide and archive live on the Project screen.
    @ViewBuilder
    private var projectChips: some View {

        ForEach(sortedActiveProjects) { project in
            RawdeaProjectChip(project: project)
        }

        ForEach(projectsViewModel.projects.filter(\.isArchived)) { project in
            RawdeaProjectChip(project: project)
        }
    }
}
