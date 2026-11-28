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
    @State private var section = ProjectSection.timeline
    @State private var followers: [PostAuthor]?
    @State private var seenBefore: Date?
    @State private var isEditingDescription = false

    // Early arrival
    @State private var hasCheckedArrival = false
    @State private var arrivalCount: Int?

    private let projectService = ProjectService()

    /// The newest copy, including a stage moved on this screen.
    private var current: Project {
        changedProject ?? project
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .navigationTitle("")
        .sheet(isPresented: $isEditingDescription) {
            ProjectDescriptionSheet(project: current) { updated in
                changedProject = updated
                await onProjectChanged()
            }
        }
        .task(id: followViewModel.followerCount) {
            followers = try? await FollowingService()
                .fetchProjectFollowers(projectId: project.id)
        }
        .task(id: project.id) {
            await loadStageEvents()
        }
        .onChange(of: project.stageChangedAt) { _, _ in
            changedProject = nil
        }
        // Opening a followed Project clears its unread count.
        .task(id: followViewModel.isFollowing) {
            if followViewModel.isFollowing {
                let service = FollowingService()
                // Kept so this visit can mark what was new.
                seenBefore = try? await service
                    .fetchProjectLastSeen()[project.id]
                try? await service
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
            if !Task.isCancelled && viewModel.errorMessage == nil {
                checkEarlyArrival()
            }
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
                isEditingDescription = true
            } label: {
                Label("Description", systemImage: "text.alignleft")
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
            let updated = try await projectService.setStage(
                projectId: project.id,
                stage: stage
            )
            let events = try? await projectService
                .fetchStageEvents(projectId: project.id)
            // Together, so the track, heading and new row move as one.
            // Reduce Motion: the list does not slide.
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.6)) {
                changedProject = updated
                stageEvents = events ?? stageEvents
            }
            await onProjectChanged()
        } catch {
            stageErrorMessage = PublicationErrorMessage.from(error)
        }
    }

    // MARK: - Early arrival

    // Decided on the first complete load of each page, so
    // refreshing does not replay it.
    private func checkEarlyArrival() {

        guard !hasCheckedArrival else { return }
        hasCheckedArrival = true

        guard EarlyArrival.shouldPlay(
            stage: current.stage,
            postCount: viewModel.posts.count
        ) else {
            return
        }

        arrivalCount = viewModel.posts.count
    }

    // MARK: - Header

    private var ownerName: String? {
        guard let ownerProfile else { return nil }
        let name = ownerProfile.displayname.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? ownerProfile.username : name
    }

    private var startedText: String {
        "started \(current.createdAt.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private var stageSummary: String {
        let since = current.stageChangedAt.formatted(.dateTime.day().month(.abbreviated))
        let posts = viewModel.posts.count
        let open = viewModel.posts.filter {
            $0.kind == .question && $0.bestReplyId == nil && !$0.isHidden
        }.count
        let questions = open == 0
            ? "No open questions"
            : open == 1 ? "1 open question" : "\(open) open questions"
        return "\(current.stage.title) since \(since) · \(posts == 1 ? "1 post" : "\(posts) posts") · \(questions)"
    }

    private var projectHeader: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {

            HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

                VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

                    Text(current.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(RawdeaPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    // Who it belongs to, linking to their profile.
                    Button {
                        openPostRoute?(.author(current.userId))
                    } label: {
                        Text(ownerProfile.map { "\($0.username) · \(startedText)" } ?? startedText)
                            .font(RawdeaTypography.secondary)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                            .multilineTextAlignment(.leading)
                            .frame(minHeight: RawdeaSpacing.minimumTouchTarget, alignment: .top)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens profile")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !dynamicTypeSize.isAccessibilitySize {
                    RawdeaInitialAvatar(
                        name: current.name,
                        size: 68,
                        font: .title.weight(.bold)
                    )
                }
            }

            if isOwner && (current.isHidden || current.isArchived) {
                Label(
                    current.isArchived ? "Archived" : "Hidden",
                    systemImage: current.isArchived ? "archivebox" : "eye.slash"
                )
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
            }

            if !current.about.isEmpty {
                Text(current.about)
                    .font(RawdeaTypography.postBody)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RawdeaStageProgress(
                stage: current.stage,
                summary: stageSummary,
                postCount: viewModel.posts.count,
                arrivalCount: arrivalCount,
                onArrivalEnd: { arrivalCount = nil }
            )

            if followViewModel.hasLoaded &&
               !followViewModel.isOwnProject &&
               !current.isHidden &&
               !current.isArchived {

                followButton
            }

            if let error = followViewModel.errorMessage {

                RawdeaInlineError(message: error)

                if !followViewModel.hasLoaded {
                    Button("Retry Follow Status") {
                        Task {
                            await followViewModel.load(project: project)
                        }
                    }
                    .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.xs)
    }

    private var followButton: some View {

        let isFollowing = followViewModel.isFollowing

        return Button {
            Task {
                await followViewModel.toggleFollow(project: project)
            }
        } label: {
            HStack(spacing: RawdeaSpacing.xs) {
                if followViewModel.isUpdating {
                    ProgressView()
                        .tint(isFollowing ? RawdeaPalette.primaryText : RawdeaPalette.onPrimaryFill)
                }
                Text(isFollowing ? "Following" : "Follow")
            }
            .font(RawdeaTypography.authorName)
            .foregroundStyle(isFollowing ? RawdeaPalette.primaryText : RawdeaPalette.onPrimaryFill)
            .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
            .background(
                isFollowing ? RawdeaPalette.canvas : RawdeaPalette.primaryFill,
                in: RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                    .strokeBorder(RawdeaPalette.activityOutline)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .disabled(followViewModel.isUpdating)
        .accessibilityLabel(isFollowing ? "Unfollow Project" : "Follow Project")
        .accessibilityIdentifier("project-follow-action")
    }

    // MARK: - Sections

    private var sectionTabs: some View {

        HStack(spacing: 0) {
            ForEach(ProjectSection.allCases, id: \.self) { item in
                let isSelected = section == item

                Button {
                    section = item
                } label: {
                    Text(item.rawValue)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(isSelected ? RawdeaPalette.primaryText : RawdeaPalette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? RawdeaPalette.accent : RawdeaPalette.divider)
                                .frame(height: isSelected ? 2 : 0.5)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.top, RawdeaSpacing.sm)
    }

    @ViewBuilder
    private var peopleRows: some View {

        if let ownerProfile {
            personRow(
                id: ownerProfile.id,
                name: ownerName ?? ownerProfile.username,
                detail: "Owner"
            )
            .timelineListRow()
        }

        if let followers {

            Text(followViewModel.followerCount == 1
                 ? "1 follower"
                 : "\(followViewModel.followerCount) followers")
                .font(RawdeaTypography.secondary.weight(.medium))
                .foregroundStyle(RawdeaPalette.secondaryText)
                .padding(.horizontal, RawdeaSpacing.screenInset)
                .padding(.vertical, RawdeaSpacing.xs)
                .timelineListRow()

            ForEach(followers, id: \.id) { person in
                personRow(
                    id: person.id,
                    name: person.displayName.isEmpty ? person.username : person.displayName,
                    detail: "@\(person.username)"
                )
                .timelineListRow()
            }

        } else {

            RawdeaLoadingIndicator("Loading people...")
                .frame(maxWidth: .infinity)
                .padding(.vertical, RawdeaSpacing.lg)
                .timelineListRow()
        }
    }

    private func personRow(id: UUID, name: String, detail: String) -> some View {

        Button {
            openPostRoute?(.author(id))
        } label: {
            HStack(spacing: RawdeaSpacing.sm) {
                RawdeaInitialAvatar(name: name)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                    Text(detail)
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
            .padding(.vertical, RawdeaSpacing.xs)
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens profile")
    }

    private var aboutRows: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {
            Text(current.about.isEmpty ? "No description yet." : current.about)
                .foregroundStyle(current.about.isEmpty
                    ? RawdeaPalette.secondaryText
                    : RawdeaPalette.primaryText)
            Text("Started \(current.createdAt.formatted(.dateTime.day().month().year()))")
                .foregroundStyle(RawdeaPalette.secondaryText)
            ForEach(stageEvents) { event in
                Text("Moved to \(event.toStage.title) on \(event.createdAt.formatted(.dateTime.day().month().year()))")
                    .foregroundStyle(RawdeaPalette.secondaryText)
            }
        }
        .font(RawdeaTypography.postBody)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RawdeaSpacing.screenInset)
    }

    // MARK: - Project posts

    private var projectPosts: some View {

        List {

            // The header now scrolls with the
            // remaining Project content.

            projectHeader
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(
                RawdeaPalette.canvas
            )

            if let question = openQuestion, section == .timeline {
                openQuestionCard(question)
                    .timelineListRow()
            }

            sectionTabs
                .timelineListRow()

            if section == .people {

                peopleRows

            } else if section == .about {

                aboutRows
                    .timelineListRow()

            // MARK: - Loading

            } else if viewModel.isLoading &&
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
                        groupHeader(group.stage, range: range(of: group))
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
                Text("\(Image(systemName: PostKind.question.symbol)) Open question · \(post.replyCount == 1 ? "1 answer" : "\(post.replyCount) answers")")
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

    /// "since 3 Nov" for the current stage, "Sep 2026 to 3 Nov" before.
    private func range(of group: ProjectTimeline.Group) -> String {
        let all = timelineGroups
        guard let index = all.firstIndex(where: { $0.id == group.id }) else {
            return ""
        }
        func day(_ date: Date) -> String {
            date.formatted(.dateTime.day().month(.abbreviated))
        }
        let start = group.startedAt ?? current.createdAt
        if index == 0 {
            return "since \(day(start))"
        }
        guard let end = all[index - 1].startedAt else { return "" }
        return "\(day(start)) to \(day(end))"
    }

    private func groupHeader(_ stage: ProjectStage, range: String) -> some View {

        HStack(spacing: RawdeaSpacing.xs) {
            Text(stage.title)
                .font(RawdeaTypography.metadata.weight(.semibold))
                .foregroundStyle(RawdeaPalette.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(range)
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
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
            RawdeaTimelineRow(
                date: post.createdAt,
                isStageChange: false,
                isNew: seenBefore.map { post.createdAt > $0 } ?? false
            ) {
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
                    .font(RawdeaTypography.metadata.weight(.semibold))
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, RawdeaSpacing.sm)
                    .padding(.vertical, RawdeaSpacing.xxs)
                    .overlay {
                        Capsule().strokeBorder(RawdeaPalette.primaryText)
                    }
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
    var isNew = false
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
                .fill(isStageChange
                    ? RawdeaPalette.primaryText
                    : isNew ? RawdeaPalette.accent : RawdeaPalette.canvas)
                .overlay {
                    Circle().strokeBorder(
                        isStageChange
                            ? RawdeaPalette.primaryText
                            : isNew ? RawdeaPalette.accent : RawdeaPalette.secondaryText,
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

private enum ProjectSection: String, CaseIterable {
    case timeline = "Timeline"
    case people = "People"
    case about = "About"
}

private extension View {

    func timelineListRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(RawdeaPalette.canvas)
    }
}
