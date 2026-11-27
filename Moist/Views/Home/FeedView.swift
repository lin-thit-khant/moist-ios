//
//  FeedView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//

import SwiftUI

struct FeedView: View {

    @ObservedObject var viewModel: FeedViewModel

    let currentUserId: UUID?
    let newlyPublishedPostID: UUID?
    let onCreatePost: () -> Void

    @State private var selectedPostForEditing: Post?
    @State private var stageRows: [HomeStageRow] = []

    // The feed still reads without its stage changes.
    private func loadStageRows() async {
        stageRows = (try? await ProjectService().fetchRecentStageRows()) ?? []
    }

    var body: some View {
        RawdeaHomeFeedList(
            posts: viewModel.posts,
            stageRows: stageRows,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            hasLoadError: viewModel.errorMessage != nil,
            hasMore: viewModel.hasMore,
            isLoadingMore: viewModel.isLoadingMore,
            hasPaginationError: viewModel.paginationErrorMessage != nil,
            emptySymbol: "text.bubble",
            emptyTitle: "No posts yet",
            emptyMessage: "Share the first idea with Rawdea.",
            emptyActionTitle: "Create a post",
            emptyAction: onCreatePost,
            refresh: {
                await viewModel.refreshPosts()
                await loadStageRows()
            },
            loadMore: viewModel.loadMorePosts
        ) { post in
            PostRowView(
                post: post,
                currentUserId: currentUserId,
                onEdit: { selectedPostForEditing = post },
                onDelete: {
                    Task { await viewModel.deletePost(postId: post.id) }
                },
                isReader: true
            )
        }
        .task {
            await loadStageRows()
        }
        .onAppear {
            Task {
                await viewModel.reloadVisiblePosts(keepingPublishedPost: newlyPublishedPostID)
            }
        }
        .sheet(item: $selectedPostForEditing) { post in
            EditPostView(post: post, viewModel: viewModel)
        }
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: { viewModel.deletionErrorMessage != nil },
                set: { if !$0 { viewModel.clearDeletionError() } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearDeletionError()
            }
        } message: {
            Text(viewModel.deletionErrorMessage ?? "")
        }
    }
}

struct RawdeaHomeFeedList<Row: View>: View {

    let posts: [Post]
    var stageRows: [HomeStageRow] = []
    let hasLoaded: Bool
    let isLoading: Bool
    let hasLoadError: Bool
    let hasMore: Bool
    let isLoadingMore: Bool
    let hasPaginationError: Bool
    let emptySymbol: String
    let emptyTitle: String
    let emptyMessage: String
    let emptyActionTitle: String
    let emptyAction: () -> Void
    let refresh: () async -> Void
    let loadMore: () async -> Void
    let postRow: (Post) -> Row

    @State private var showsProgress = false
    @Environment(\.rawdeaScrollingFeedHeader) private var scrollingHeader

    private var isInitialLoad: Bool {
        posts.isEmpty && !hasLoaded && !hasLoadError
    }

    var body: some View {
        List {
            if let scrollingHeader {
                scrollingHeader
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)
            }

            if posts.isEmpty {
                emptyContent
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)
            } else {
                if hasLoadError {
                    errorRow("Couldn't refresh posts.") {
                        await refresh()
                    }
                }

                ForEach(HomeFeedItem.merge(
                    posts: posts,
                    stages: stageRows,
                    hasMore: hasMore
                )) { item in
                    VStack(spacing: 0) {
                        switch item {
                        case .post(let post):
                            postRow(post)
                        case .stage(let row):
                            RawdeaStageFeedRow(row: row)
                        }

                        Divider()
                            .overlay(RawdeaPalette.divider)
                            .padding(.leading, RawdeaSpacing.feedDividerInset)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)
                }

                if hasPaginationError {
                    errorRow("Couldn't load more posts.") {
                        await loadMore()
                    }
                } else if hasMore {
                    loadMoreRow
                } else {
                    RawdeaFeedEnd()
                        .listRowSeparator(.hidden)
                        .listRowBackground(RawdeaPalette.canvas)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .rawdeaRefreshable { await refresh() }
        .task(id: isInitialLoad || isLoadingMore) {
            showsProgress = false
            guard isInitialLoad || isLoadingMore else { return }

            // Keep fast loads from flashing a spinner.
            do {
                try await Task.sleep(for: .milliseconds(250))
                showsProgress = true
            } catch {
                return
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if hasLoadError {
            RawdeaEmptyState(
                symbol: "exclamationmark.circle",
                title: "Couldn't load posts",
                message: "Check your connection and try again.",
                actionTitle: "Retry"
            ) {
                Task { await refresh() }
            }
            .disabled(isLoading)
        } else if isInitialLoad {
            RawdeaLoadingIndicator("Loading posts…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, RawdeaSpacing.xl)
                .opacity(showsProgress ? 1 : 0)
                .accessibilityHidden(!showsProgress)
        } else {
            RawdeaEmptyState(
                symbol: emptySymbol,
                title: emptyTitle,
                message: emptyMessage,
                actionTitle: emptyActionTitle,
                action: emptyAction
            )
        }
    }

    private var loadMoreRow: some View {
        let showsSpinner = isLoadingMore && showsProgress

        return Button {
            Task { await loadMore() }
        } label: {
            Text("Load More")
                .opacity(showsSpinner ? 0 : 1)
                .overlay {
                    if showsSpinner {
                        RawdeaLoadingIndicator(size: 20)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
        }
        .buttonStyle(.bordered)
        .disabled(isLoading || isLoadingMore)
        .accessibilityLabel(isLoadingMore ? "Loading more posts" : "Load More")
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowBackground(RawdeaPalette.canvas)
    }

    private func errorRow(
        _ message: String,
        retry: @escaping () async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
            RawdeaInlineError(message: message)

            Button {
                Task { await retry() }
            } label: {
                Text("Retry")
                    .font(RawdeaTypography.button)
                    .frame(
                        minWidth: RawdeaSpacing.minimumTouchTarget,
                        minHeight: RawdeaSpacing.minimumTouchTarget,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(RawdeaPalette.primaryText)
            .disabled(isLoading || isLoadingMore)
        }
        .padding(.vertical, RawdeaSpacing.xs)
        .listRowSeparator(.hidden)
        .listRowBackground(RawdeaPalette.canvas)
    }
}

// MARK: - Scrolling feed header

private struct RawdeaScrollingFeedHeaderKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

extension EnvironmentValues {
    /// A header the Home feed scrolls as its first row.
    var rawdeaScrollingFeedHeader: AnyView? {
        get { self[RawdeaScrollingFeedHeaderKey.self] }
        set { self[RawdeaScrollingFeedHeaderKey.self] = newValue }
    }
}

/// The calm end of a Home list.
struct RawdeaFeedEnd: View {

    var body: some View {
        VStack(spacing: RawdeaSpacing.xxs) {
            Text("That's everything so far.")
                .font(RawdeaTypography.authorName)
                .foregroundStyle(RawdeaPalette.primaryText)
            Text("More is still forming.")
                .font(RawdeaTypography.secondary)
                .foregroundStyle(RawdeaPalette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.vertical, RawdeaSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// "Kiln Log moved to In progress", with the stage track.
struct RawdeaStageFeedRow: View {

    let row: HomeStageRow

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            openPostRoute?(.project(row.project.id))
        } label: {
            HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

                if !dynamicTypeSize.isAccessibilitySize {
                    RawdeaProjectAvatar(name: row.project.name)
                }

                VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                    Text("\(Text(row.project.name).font(RawdeaTypography.authorName).foregroundStyle(RawdeaPalette.primaryText))  \(row.project.owner?.username ?? "")  \(PostRowView.shortAge(of: row.createdAt, at: .now))")
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.secondaryText)

                    Text("\(Image(systemName: "arrow.right.circle")) Moved to \(row.toStage.title)")
                        .font(RawdeaTypography.metadata.weight(.semibold))
                        .foregroundStyle(RawdeaPalette.primaryText)
                        .padding(.horizontal, RawdeaSpacing.sm)
                        .padding(.vertical, RawdeaSpacing.xxs)
                        .overlay {
                            Capsule().strokeBorder(RawdeaPalette.primaryText)
                        }

                    RawdeaStageTrack(stage: row.toStage)
                        .frame(maxWidth: 260)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
            .padding(.vertical, RawdeaSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(row.project.name) moved to \(row.toStage.title)")
        .accessibilityHint("Opens Project")
    }
}
