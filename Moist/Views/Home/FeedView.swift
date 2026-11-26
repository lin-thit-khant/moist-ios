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

    var body: some View {
        RawdeaHomeFeedList(
            posts: viewModel.posts,
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
            refresh: viewModel.refreshPosts,
            loadMore: viewModel.loadMorePosts
        ) { post, showsProject, continuesThread in
            PostRowView(
                post: post,
                currentUserId: currentUserId,
                onEdit: { selectedPostForEditing = post },
                onDelete: {
                    Task { await viewModel.deletePost(postId: post.id) }
                },
                showsProjectLink: showsProject,
                continuesThread: continuesThread
            )
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
    /// The post, whether to name its Project, and whether the
    /// thread line continues below it.
    let postRow: (Post, Bool, Bool) -> Row

    @State private var showsProgress = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isInitialLoad: Bool {
        posts.isEmpty && !hasLoaded && !hasLoadError
    }

    var body: some View {
        List {
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

                ForEach(RawdeaFeedEntry.entries(for: posts)) { entry in
                    VStack(spacing: 0) {
                        switch entry {
                        case .post(let post, let showsProject, let continuesThread):
                            // Large text has no thread line, so
                            // every post names its Project.
                            postRow(
                                post,
                                showsProject || dynamicTypeSize.isAccessibilitySize,
                                continuesThread
                            )
                        case .more(let project, let count, _):
                            RawdeaThreadMoreRow(project: project, count: count)
                        }

                        if entry.endsGroup {
                            Divider()
                                .overlay(RawdeaPalette.divider)
                                .padding(.horizontal, RawdeaSpacing.screenInset)
                        }
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

// MARK: - Cut-short Project thread

/// Ends a long thread with a way into its Project.
private struct RawdeaThreadMoreRow: View {

    let project: PostProject
    let count: Int

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let openPostRoute {
            Button {
                openPostRoute(.project(project.id))
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                ProjectRouteView(projectId: project.id)
            } label: {
                label
            }
            .buttonStyle(.plain)
        }
    }

    private var label: some View {
        HStack(spacing: RawdeaSpacing.sm) {
            if !dynamicTypeSize.isAccessibilitySize {
                // Closes the thread line.
                Circle()
                    .fill(RawdeaPalette.activityOutline)
                    .frame(width: RawdeaSpacing.xs, height: RawdeaSpacing.xs)
                    .frame(width: RawdeaSpacing.avatarColumn)
                    .accessibilityHidden(true)
            }

            Text("\(count) more in \(project.name)")
                .font(RawdeaTypography.metadata.weight(.semibold))
                .foregroundStyle(RawdeaPalette.secondaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: RawdeaSpacing.minimumTouchTarget,
            alignment: .leading
        )
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.bottom, RawdeaSpacing.xxs)
        .contentShape(Rectangle())
    }
}
