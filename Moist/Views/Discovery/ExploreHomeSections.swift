//
//  ExploreHomeSections.swift
//  Rawdea
//

import Combine
import SwiftUI

@MainActor
private final class ExploreHomeViewModel: ObservableObject {

    @Published private(set) var projects: [ActiveProject] = []
    @Published private(set) var questions: [Post] = []
    @Published private(set) var followedIds: Set<UUID> = []
    @Published private(set) var viewerId: UUID?
    @Published private(set) var updatingId: UUID?
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published var followError: String?

    private let discovery = DiscoveryService()
    private let following = FollowingService()
    private var requestID = UUID()

    func load(stage: ProjectStage?) async {

        let ticket = UUID()
        requestID = ticket
        errorMessage = nil

        do {
            let viewer = try await following.currentUserId()
            let active = try await discovery.fetchActiveProjects(stage: stage)
            let open = try await discovery.fetchOpenQuestions()
            let followed = try await following.fetchFollowingProjects()

            guard requestID == ticket, !Task.isCancelled else { return }

            viewerId = viewer
            projects = active
            questions = open
            followedIds = Set(followed.map(\.id))
            hasLoaded = true

        } catch is CancellationError {
            return
        } catch {
            guard requestID == ticket, !Task.isCancelled else { return }
            // Never leave stale content that may no longer be visible.
            projects = []
            questions = []
            errorMessage = "Check your connection and try again."
            hasLoaded = true
        }
    }

    func toggleFollow(_ projectId: UUID) async {

        guard updatingId == nil else { return }

        updatingId = projectId
        defer { updatingId = nil }

        do {
            if followedIds.contains(projectId) {
                try await following.unfollowProject(projectId: projectId)
                followedIds.remove(projectId)
            } else {
                try await following.followProject(projectId: projectId)
                followedIds.insert(projectId)
            }
        } catch {
            followError = "Couldn't update that follow. Try again."
        }
    }
}

/// Explore before a search: stage chips, recently active
/// Projects and open questions.
struct ExploreHomeSections: View {

    @StateObject private var viewModel = ExploreHomeViewModel()
    @State private var stage: ProjectStage?

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {

        List {

            stageChips
                .exploreRow(insets: EdgeInsets())

            if !viewModel.hasLoaded {

                RawdeaLoadingIndicator("Loading Projects...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RawdeaSpacing.xl)
                    .exploreRow()

            } else if let error = viewModel.errorMessage {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load Explore",
                    message: error,
                    actionTitle: "Try Again"
                ) {
                    Task { await viewModel.load(stage: stage) }
                }
                .exploreRow()

            } else {

                heading("Recently active Projects")

                if viewModel.projects.isEmpty {
                    note(stage == nil
                         ? "No Projects yet."
                         : "No Projects at this stage yet.")
                }

                ForEach(viewModel.projects) { item in
                    projectRow(item)
                        .listRowBackground(RawdeaPalette.canvas)
                        .listRowSeparatorTint(RawdeaPalette.divider)
                }

                heading("Open questions")

                if viewModel.questions.isEmpty {
                    note("No open questions right now.")
                }

                ForEach(viewModel.questions) { post in
                    questionRow(post)
                        .listRowBackground(RawdeaPalette.canvas)
                        .listRowSeparatorTint(RawdeaPalette.divider)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .rawdeaRefreshable { await viewModel.load(stage: stage) }
        .task(id: stage) { await viewModel.load(stage: stage) }
        .onAppear {
            guard viewModel.hasLoaded else { return }
            Task { await viewModel.load(stage: stage) }
        }
        .alert(
            "Couldn't update follow",
            isPresented: Binding(
                get: { viewModel.followError != nil },
                set: { if !$0 { viewModel.followError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.followError ?? "")
        }
    }

    private var stageChips: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RawdeaSpacing.xs) {
                RawdeaChip(title: "All stages", isSelected: stage == nil) {
                    stage = nil
                }
                ForEach(ProjectStage.allCases, id: \.self) { item in
                    RawdeaChip(title: item.title, isSelected: stage == item) {
                        stage = item
                    }
                }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Project stage")
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(RawdeaTypography.secondary.weight(.medium))
            .foregroundStyle(RawdeaPalette.secondaryText)
            .accessibilityAddTraits(.isHeader)
            .exploreRow()
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(RawdeaTypography.secondary)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .padding(.vertical, RawdeaSpacing.sm)
            .exploreRow()
    }

    private func projectRow(_ item: ActiveProject) -> some View {

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: RawdeaSpacing.sm))

        return layout {

            Button {
                openPostRoute?(.project(item.project.id))
            } label: {
                HStack(spacing: RawdeaSpacing.sm) {

                    if !dynamicTypeSize.isAccessibilitySize {
                        RawdeaProjectAvatar(name: item.project.name)
                    }

                    VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                        Text(item.project.name)
                            .font(RawdeaTypography.authorName)
                            .foregroundStyle(RawdeaPalette.primaryText)
                        Text("\(item.project.stage.title) · \(PostRowView.relativeAge(of: item.latest.createdAt, at: .now))")
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                        Text(item.latest.content)
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                            .lineLimit(2)
                    }
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens Project")

            if item.project.userId != viewModel.viewerId {
                RawdeaFollowButton(
                    isFollowing: viewModel.followedIds.contains(item.id),
                    isUpdating: viewModel.updatingId == item.id,
                    followLabel: "Follow \(item.project.name)",
                    unfollowLabel: "Unfollow \(item.project.name)"
                ) {
                    Task { await viewModel.toggleFollow(item.id) }
                }
            }
        }
    }

    private func questionRow(_ post: Post) -> some View {

        Button {
            openPostRoute?(.discussion(post.id))
        } label: {
            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                Text("\(Image(systemName: PostKind.question.symbol)) \(post.project?.name ?? "Project") · Open")
                    .font(RawdeaTypography.metadata.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)
                Text(post.content)
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the question")
    }
}

private extension View {

    func exploreRow(
        insets: EdgeInsets? = nil
    ) -> some View {
        listRowInsets(insets)
            .listRowSeparator(.hidden)
            .listRowBackground(RawdeaPalette.canvas)
    }
}
