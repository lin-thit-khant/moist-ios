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

    // Timeline
    @State private var stageEvents: [ProjectStageEvent] = []
    @State private var kindFilter: PostKind?
    @State private var changedProject: Project?
    @State private var stageErrorMessage: String?

    private let projectService = ProjectService()

    /// The newest copy, including a stage moved on this screen.
    private var current: Project {
        changedProject ?? project
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .task(id: project.id) {
            await loadStageEvents()
        }
        .onChange(of: project.stageChangedAt) { _, _ in
            changedProject = nil
        }
        // Opening a followed Project clears its unread count.
        .task(id: followViewModel.isFollowing) {
            if followViewModel.isFollowing {
                try? await FollowingService()
                    .markProjectSeen(projectId: project.id)
            }
        }
        .alert(
            "Couldn't change the stage",
            isPresented: Binding(
                get: { stageErrorMessage != nil },
                set: { if !$0 { stageErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(stageErrorMessage ?? "")
        }
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
            Menu {
                ForEach(ProjectStage.allCases, id: \.self) { stage in
                    Button {
                        Task { await moveStage(to: stage) }
                    } label: {
                        if stage == current.stage {
                            Label(stage.title, systemImage: "checkmark")
                        } else {
                            Text(stage.title)
                        }
                    }
                }
            } label: {
                Label("Stage", systemImage: "arrow.right.circle")
            }

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

    // MARK: - Stage

    private func loadStageEvents() async {
        // The timeline still reads without its stage history.
        if let events = try? await projectService
            .fetchStageEvents(projectId: project.id) {
            stageEvents = events
        }
    }

    private func moveStage(to stage: ProjectStage) async {

        guard stage != current.stage else { return }

        do {
            changedProject = try await projectService.setStage(
                projectId: project.id,
                stage: stage
            )
            await loadStageEvents()
            await onProjectChanged()
        } catch {
            stageErrorMessage = PublicationErrorMessage.from(error)
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

    private var stageSummary: String {
        let since = current.stageChangedAt.formatted(.dateTime.day().month().year())
        return "\(current.stage.title) since \(since)"
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
                    project: current,
                    showsOwnerStatus: isOwner
                )

                RawdeaStageTrack(stage: current.stage)

                Text(stageSummary)
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

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

            // MARK: - Timeline

            } else {

                if let question = openQuestion {
                    openQuestionCard(question)
                        .timelineListRow()
                }

                filterChips
                    .timelineListRow()

                if timelineGroups.isEmpty {

                    Text("Nothing here yet.")
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RawdeaSpacing.lg)
                        .timelineListRow()
                }

                ForEach(timelineGroups) { group in

                    // A filtered list is not a history, so it
                    // drops the stage headings.
                    if kindFilter == nil {
                        groupHeader(group.stage)
                            .timelineListRow()
                    }

                    ForEach(group.items) { item in
                        timelineRow(item)
                            .timelineListRow()
                    }
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

        .rawdeaRefreshable {

            await viewModel.loadPosts(
                projectId: project.id
            )
            await loadStageEvents()
        }
    }

    // MARK: - Timeline

    private var timelineGroups: [ProjectTimeline.Group] {
        ProjectTimeline.groups(
            posts: viewModel.posts.filter {
                kindFilter == nil || $0.kind == kindFilter
            },
            events: kindFilter == nil ? stageEvents : [],
            currentStage: current.stage
        )
    }

    private var openQuestion: Post? {
        viewModel.posts.first {
            $0.kind == .question && $0.bestReplyId == nil && !$0.isHidden
        }
    }

    private func openQuestionCard(_ post: Post) -> some View {

        Button {
            openPostRoute?(.discussion(post.id))
        } label: {
            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                Text("\(Image(systemName: PostKind.question.symbol)) Open question")
                    .font(RawdeaTypography.metadata.weight(.semibold))
                    .foregroundStyle(RawdeaPalette.secondaryText)
                Text(post.content)
                    .font(RawdeaTypography.body)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RawdeaSpacing.sm)
            .background(
                RawdeaPalette.surface,
                in: RoundedRectangle(cornerRadius: RawdeaSpacing.cardRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the question")
    }

    private var filterChips: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RawdeaSpacing.xs) {
                RawdeaChip(title: "All", isSelected: kindFilter == nil) {
                    kindFilter = nil
                }
                ForEach([PostKind.question, .progress, .decision, .note], id: \.self) { kind in
                    RawdeaChip(title: kind.filterTitle, isSelected: kindFilter == kind) {
                        kindFilter = kind
                    }
                }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
        }
        .padding(.top, RawdeaSpacing.xs)
    }

    private func groupHeader(_ stage: ProjectStage) -> some View {

        HStack(spacing: RawdeaSpacing.xs) {
            Text(stage.title)
                .font(RawdeaTypography.metadata.weight(.semibold))
                .foregroundStyle(RawdeaPalette.primaryText)
                .accessibilityAddTraits(.isHeader)
            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.sm)
        .padding(.bottom, RawdeaSpacing.xxs)
    }

    @ViewBuilder
    private func timelineRow(_ item: ProjectTimeline.Item) -> some View {

        switch item {

        case .post(let post):
            RawdeaTimelineRow(date: post.createdAt, isStageChange: false) {
                PostRowView(
                    post: post,
                    currentUserId: currentUserId,
                    onEdit: {
                        selectedPostForEditing = post
                    },
                    onDelete: {
                        Task {
                            await viewModel.deletePost(postId: post.id)
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
                    showsProjectLink: false,
                    isTimeline: true
                )
            }

        case .stageChange(let event):
            RawdeaTimelineRow(date: event.createdAt, isStageChange: true) {
                Text("\(Image(systemName: "arrow.right.circle")) Moved to \(event.toStage.title)")
                    .font(RawdeaTypography.authorName)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, RawdeaSpacing.sm)
                    .accessibilityLabel("Moved to \(event.toStage.title)")
            }
        }
    }

}

// MARK: - Timeline row

/// The date and rail beside a timeline entry. Large text moves
/// the date above and drops the rail.
private struct RawdeaTimelineRow<Content: View>: View {

    let date: Date
    let isStageChange: Bool
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .footnote)
    private var dateWidth = RawdeaSpacing.minimumTouchTarget

    private var dateText: some View {
        Text(date.formatted(.dateTime.day().month(.abbreviated)))
            .font(RawdeaTypography.metadata)
            .foregroundStyle(RawdeaPalette.secondaryText)
    }

    var body: some View {

        Group {
            if dynamicTypeSize.isAccessibilitySize {

                VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                    dateText
                    content
                }

            } else {

                HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

                    dateText
                        .multilineTextAlignment(.trailing)
                        .frame(width: dateWidth, alignment: .trailing)

                    content
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, RawdeaSpacing.lg)
                        .overlay(alignment: .topLeading) { rail }
                }
            }
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.xs)
    }

    private var rail: some View {

        ZStack(alignment: .top) {
            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(width: 1)
            Circle()
                .fill(isStageChange ? RawdeaPalette.primaryText : RawdeaPalette.canvas)
                .overlay {
                    Circle().strokeBorder(
                        isStageChange ? RawdeaPalette.primaryText : RawdeaPalette.secondaryText,
                        lineWidth: 1.5
                    )
                }
                .frame(width: RawdeaSpacing.xs + 1, height: RawdeaSpacing.xs + 1)
                .padding(.top, RawdeaSpacing.xxs)
        }
        .frame(width: RawdeaSpacing.xs + 1)
        .padding(.bottom, -RawdeaSpacing.xs)
        .accessibilityHidden(true)
    }
}

private extension View {

    func timelineListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(RawdeaPalette.canvas)
    }
}
