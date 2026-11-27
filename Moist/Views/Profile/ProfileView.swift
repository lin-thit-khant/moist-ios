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
    
    @State private var isShowingCreateProject = false
    @State private var newProjectName = ""
    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    @State private var projectToRename: Project?
    
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
                        
                        
                        profileActions(profile)

                        RawdeaProfileWorkSections(
                            pinnedProjects: sortedActiveProjects.filter(\.isPinned),
                            projectRow: projectRow,
                            posts: { postsSection(profile: profile) },
                            projects: { projectsSection }
                        )
                        .sheet(isPresented: $isShowingCreateProject) {
                            NavigationStack {
                                Form {
                                    TextField("Project name", text: $newProjectName)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled()
                                    if let errorMessage = projectsViewModel.errorMessage {
                                        Text(errorMessage)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .scrollContentBackground(.hidden)
                                .background(
                                    RawdeaPalette.canvas
                                )
                                .navigationTitle("New Project")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Cancel") {
                                            isShowingCreateProject = false
                                        }
                                    }
                                    
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Create") {
                                            Task {
                                                let created = await projectsViewModel.creatProject(
                                                    name: newProjectName
                                                )
                                                
                                                if created {
                                                    isShowingCreateProject = false
                                                    newProjectName = ""
                                                }
                                            }
                                        }
                                        .disabled(
                                            newProjectName.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty ||
                                            RawdeaTextLength.count(newProjectName) > 80 ||
                                            projectsViewModel.isCreating
                                        )
                                    }
                                }
                                .interactiveDismissDisabled(projectsViewModel.isCreating)
                            }
                        }
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
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                NavigationLink(
                    value: RawdeaPostRoute.settings
                ) {

                    Image(systemName: "gearshape")
                        .font(.system(.body))
                        .frame(
                            width:
                                RawdeaSpacing.minimumTouchTarget,
                            height:
                                RawdeaSpacing.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
                .accessibilityHint(
                    "Opens account settings"
                )
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
        .sheet(item: $projectToRename) { project in
            ProjectRenameSheet(
                viewModel: projectsViewModel,
                project: project
            )
        }
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

    // MARK: - Profile actions

    // Three equal pills, stacked at accessibility sizes.
    private func profileActions(_ profile: Profile) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(alignment: .top, spacing: RawdeaSpacing.xs))

        return layout {
            NavigationLink {
                EditProfileView(
                    viewModel: viewModel,
                    profile: profile
                )
            } label: {
                RawdeaOutlinePillLabel(title: "Edit Profile")
            }
            .buttonStyle(.plain)

            NavigationLink(value: RawdeaPostRoute.following) {
                RawdeaOutlinePillLabel(title: "Following")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens people and Projects you follow")

            NavigationLink(value: RawdeaPostRoute.savedPosts) {
                RawdeaOutlinePillLabel(title: "Saved")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Saved Posts")
        }
    }

    private var projectsSection: some View {
        let archivedProjects = projectsViewModel.projects.filter(\.isArchived)

        return VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {
            Button {
                projectsViewModel.clearError()
                newProjectName = ""
                isShowingCreateProject = true
            } label: {
                Label("New Project", systemImage: "plus")
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let errorMessage = projectsViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if projectsViewModel.isLoading && projectsViewModel.projects.isEmpty {
                RawdeaLoadingIndicator("Loading projects...")
            } else if projectsViewModel.projects.isEmpty {
                if projectsViewModel.errorMessage == nil {
                    projectsNote("Projects keep related posts together. Start one for something you're working on.")
                }
            } else {
                let unpinnedProjects = sortedActiveProjects.filter { !$0.isPinned }

                if unpinnedProjects.isEmpty {
                    projectsNote(
                        sortedActiveProjects.isEmpty
                        ? "You have no active Projects."
                        : "All your active Projects are pinned above."
                    )
                }

                ForEach(unpinnedProjects, content: projectRow)

                if !archivedProjects.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: RawdeaSpacing.sm) {
                            ForEach(archivedProjects, content: projectRow)
                        }
                    } label: {
                        Text("Archived Projects")
                            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func projectsNote(_ text: String) -> some View {
        Text(text)
            .font(RawdeaTypography.secondary)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func latestNote(for projectId: UUID) -> String? {
        postsViewModel.posts.first {
            $0.projectId == projectId && !$0.isHidden
        }?.content
    }
    
    private func projectRow(
        _ project: Project
    ) -> some View {

        RawdeaProjectSurface {

            HStack(
                alignment: .center,
                spacing: RawdeaSpacing.sm
            ) {

                // The whole Project preview opens
                // the routed Project destination.
                NavigationLink(
                    value: RawdeaPostRoute.project(
                        project.id
                    )
                ) {

                    RawdeaProjectCard(
                        project: project,
                        preview: latestNote(
                            for: project.id
                        ),
                        showsOwnerStatus: true
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: RawdeaSpacing.minimumTouchTarget,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    "Opens Project"
                )

                // Owner actions remain independent
                // of the navigation target.
                Menu {

                    Button {


                        projectsViewModel.clearError()

                        projectToRename = project

                    } label: {

                        Label(
                            "Rename",
                            systemImage: "pencil"
                        )
                    }

                    Button {

                        Task {

                            _ = await projectsViewModel
                                .setArchived(
                                    projectId: project.id,
                                    archived:
                                        !project.isArchived
                                )
                        }

                    } label: {

                        Label(
                            project.isArchived
                            ? "Unarchive"
                            : "Archive",
                            systemImage: "archivebox"
                        )
                    }

                    Button {

                        Task {

                            _ = await projectsViewModel
                                .setHidden(
                                    projectId: project.id,
                                    hidden: !project.isHidden
                                )
                        }

                    } label: {

                        Label(
                            project.isHidden
                            ? "Make Public"
                            : "Hide",
                            systemImage:
                                project.isHidden
                                ? "eye"
                                : "eye.slash"
                        )
                    }

                    Button {

                        Task {

                            _ = await projectsViewModel
                                .setPinned(
                                    projectId: project.id,
                                    pinned: !project.isPinned
                                )
                        }

                    } label: {

                        Label(
                            project.isPinned
                            ? "Unpin"
                            : "Pin",
                            systemImage:
                                project.isPinned
                                ? "pin.slash"
                                : "pin"
                        )
                    }

                } label: {

                    Image(systemName: "ellipsis")
                        .font(.system(.body))
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .frame(
                            width:
                                RawdeaSpacing.minimumTouchTarget,
                            height:
                                RawdeaSpacing.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .disabled(
                    projectsViewModel.isUpdating
                )
                .accessibilityLabel(
                    "Options for \(project.name)"
                )
            }
        }
    }


}
