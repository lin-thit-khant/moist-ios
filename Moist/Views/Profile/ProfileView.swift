//
//  ProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import SwiftUI

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
        
    @State private var isAccountSuspended = false
    
    @StateObject private var postsViewModel = FeedViewModel()
    
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    @State private var isShowingCreateProject = false
    @State private var newProjectName = ""
    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    @State private var projectToRename: Project?
    @State private var projectNameDraft = ""
    
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
                ProgressView("Loading profile...")
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
                        
                        
                        NavigationLink {

                            EditProfileView(
                                viewModel: viewModel,
                                profile: profile
                            )

                        } label: {

                            Text("Edit Profile")
                                .font(RawdeaTypography.button)
                                .foregroundStyle(
                                    RawdeaPalette.onAccent
                                )
                                .frame(maxWidth: .infinity)
                                .frame(
                                    minHeight:
                                        RawdeaSpacing.minimumTouchTarget
                                )
                                .padding(
                                    .vertical,
                                    RawdeaSpacing.xs
                                )
                                .background(
                                    RawdeaPalette.accent,
                                    in: RoundedRectangle(
                                        cornerRadius:
                                            RawdeaSpacing.buttonRadius
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        
                        NavigationLink(
                            value: RawdeaPostRoute.following
                        ) {

                            Label(
                                "Following",
                                systemImage: "person.2"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        
                        // MARK: - Saved Posts

                        NavigationLink(
                            value: RawdeaPostRoute.savedPosts
                        ) {

                            Label(
                                "Saved Posts",
                                systemImage: "bookmark"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        
                        #if DEBUG

                        // Temporary design-system testing entry.
                        // Only included in development builds.

                        NavigationLink {

                            RawdeaDesignPreviewView()

                        } label: {

                            Label(
                                "Design System Preview",
                                systemImage: "paintpalette"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)

                        #endif


                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text("Free posts")
                                .font(RawdeaTypography.sectionTitle)
                                .foregroundStyle(
                                    RawdeaPalette.primaryText
                                )
                                .accessibilityAddTraits(.isHeader)
                            
                            if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                                
                                ProgressView("Loading posts...")
                                
                            } else if let errorMessage = postsViewModel.errorMessage {
                                
                                Text(errorMessage)
                                    .foregroundStyle(.secondary)
                                
                                Button("Try Again") {
                                    Task {
                                        await postsViewModel.loadPosts(userId: profile.id)
                                    }
                                }
                                
                            } else if postsViewModel.posts.allSatisfy({ $0.projectId != nil }) {
                                
                                Text("Your thoughts will appear here.")
                                    .foregroundStyle(.secondary)
                                
                            } else {
                                
                                LazyVStack(spacing: 0) {
                                    
                                    ForEach(
                                        postsViewModel.posts.filter { $0.projectId == nil }
                                    ) { post in
                                        
                                        PostRowView(
                                            post: post,
                                            currentUserId: profile.id,
                                            onEdit: {
                                                selectedPostForEditing = post
                                            },
                                            onDelete: {
                                                Task {
                                                    await postsViewModel.deletePost(
                                                        postId: post.id
                                                    )
                                                }
                                            },
                                            onMove: {
                                                selectedPostForMoving = post
                                            },
                                            onHide: {
                                                Task {
                                                    await postsViewModel.setPostHidden(
                                                        postId: post.id,
                                                        hidden: !post.isHidden
                                                    )
                                                }
                                            }
                                        )
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            HStack {
                                Text("Projects")
                                    .font(RawdeaTypography.sectionTitle)
                                    .foregroundStyle(
                                        RawdeaPalette.primaryText
                                    )
                                    .accessibilityAddTraits(.isHeader)
                                
                                Spacer()
                                
                                Button {

                                    projectsViewModel.clearError()
                                    newProjectName = ""
                                    isShowingCreateProject = true

                                } label: {

                                    Label(
                                        "New Project",
                                        systemImage: "plus"
                                    )
                                    .font(RawdeaTypography.metadata)
                                    .foregroundStyle(
                                        RawdeaPalette.accent
                                    )
                                    .frame(
                                        minHeight:
                                            RawdeaSpacing.minimumTouchTarget
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let errorMessage = projectsViewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            if projectsViewModel.isLoading &&
                                projectsViewModel.projects.isEmpty {
                                
                                ProgressView("Loading projects...")
                                
                            } else if projectsViewModel.projects.isEmpty {
                                if projectsViewModel.errorMessage == nil {
                                    Text("Your Projects will appear here.")
                                        .foregroundStyle(.secondary)
                                }
                                
                            } else {
                                
                                ForEach(
                                    sortedActiveProjects
                                ) { project in
                                    projectRow(project)
                                }

                                if projectsViewModel.projects.contains(
                                    where: { $0.isArchived }
                                ) {
                                    DisclosureGroup("Archived Projects") {
                                        ForEach(
                                            projectsViewModel.projects.filter { $0.isArchived }
                                        ) { project in
                                            projectRow(project)
                                        }
                                    }
                                }

                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                                            newProjectName.count > 80 ||
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
                .task(id: profile.id) {
                    await postsViewModel.loadPosts(userId: profile.id)
                    
                    await projectsViewModel.loadProjects(userId: profile.id)
                }
                .refreshable {
                    await viewModel.loadProfile()
                    
                    isAccountSuspended = (
                        try? await ModerationService()
                            .isMyAccountSuspended()
                    ) ?? false

                    if let profile = viewModel.profile {
                        await postsViewModel.loadPosts(userId: profile.id)
                    }
                    
                    await projectsViewModel.loadProjects(userId: profile.id)
                }
            } else {
                ProgressView("Preparing profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(item: $projectToRename, content: { project in
            NavigationStack {
                Form {
                    Section("Project name") {
                        TextField(
                            "Name",
                            text: $projectNameDraft
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    }
                    
                    if let error = projectsViewModel.errorMessage {
                        Section {
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(
                    RawdeaPalette.canvas
                )
                .navigationTitle("Rename Project")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            projectToRename = nil
                        }
                        .disabled(projectsViewModel.isUpdating)
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                let success = await projectsViewModel
                                    .renameProject(
                                        projectId: project.id,
                                        name: projectNameDraft
                                    )
                                
                                if success {
                                    projectToRename = nil
                                }
                            }
                        }
                        .disabled(
                            projectNameDraft.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty ||
                            projectNameDraft.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).count > 80 ||
                            projectsViewModel.isUpdating
                        )
                    }
                }
                .interactiveDismissDisabled(projectsViewModel.isUpdating)
            }
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

                        projectNameDraft = project.name

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
