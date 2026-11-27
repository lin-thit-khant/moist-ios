//
//  FollowingFeedView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import SwiftUI

struct FollowingFeedView: View {

    @ObservedObject var viewModel: FollowingFeedViewModel
    let onExplore: () -> Void

    var body: some View {
        Group {
            if viewModel.projectRows.isEmpty {
                postFeed
            } else {
                FollowedProjectList(
                    rows: viewModel.projectRows,
                    hasLoadError: viewModel.errorMessage != nil,
                    refresh: viewModel.refreshPosts
                )
            }
        }
        .onAppear {
            Task { await viewModel.reloadVisiblePosts() }
        }
    }

    // People followed without any Project keep the post feed.
    private var postFeed: some View {
        RawdeaHomeFeedList(
            posts: viewModel.posts,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            hasLoadError: viewModel.errorMessage != nil,
            hasMore: viewModel.hasMore,
            isLoadingMore: viewModel.isLoadingMore,
            hasPaginationError: viewModel.paginationErrorMessage != nil,
            emptySymbol: "person.2",
            emptyTitle: viewModel.hasFollowedSources ? "No posts from your follows yet" : "Your Following feed is empty",
            emptyMessage: viewModel.hasFollowedSources
                ? "Explore more people and projects to follow."
                : "Follow people or projects to see their posts here.",
            emptyActionTitle: "Explore",
            emptyAction: onExplore,
            refresh: viewModel.refreshPosts,
            loadMore: viewModel.loadMorePosts
        ) { post in
            PostRowView(
                post: post,
                isReader: true
            )
        }
    }
}

// MARK: - Project list

private struct FollowedProjectList: View {

    let rows: [FollowedProjectRow]
    let hasLoadError: Bool
    let refresh: () async -> Void

    @Environment(\.rawdeaScrollingFeedHeader) private var scrollingHeader

    private var changed: [FollowedProjectRow] {
        rows.filter { $0.newCount > 0 }
    }

    private var caughtUp: [FollowedProjectRow] {
        rows.filter { $0.newCount == 0 }
    }

    var body: some View {
        List {
            if let scrollingHeader {
                scrollingHeader
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)
            }

            if hasLoadError {
                RawdeaInlineError(message: "Couldn't refresh Projects. Pull to try again.")
                    .listRowSeparator(.hidden)
                    .listRowBackground(RawdeaPalette.canvas)
            }

            section("Changed since you last looked", rows: changed)
            section("Caught up", rows: caughtUp)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .rawdeaRefreshable { await refresh() }
    }

    @ViewBuilder
    private func section(_ title: String, rows: [FollowedProjectRow]) -> some View {
        if !rows.isEmpty {
            Text(title)
                .font(RawdeaTypography.secondary.weight(.medium))
                .foregroundStyle(RawdeaPalette.secondaryText)
                .accessibilityAddTraits(.isHeader)
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)

            ForEach(rows) { row in
                FollowedProjectRowView(row: row)
                    .listRowBackground(RawdeaPalette.canvas)
                    .listRowSeparatorTint(RawdeaPalette.divider)
            }
        }
    }
}

private struct FollowedProjectRowView: View {

    let row: FollowedProjectRow

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button {
            openPostRoute?(.project(row.project.id))
        } label: {
            HStack(alignment: .center, spacing: RawdeaSpacing.sm) {

                if !dynamicTypeSize.isAccessibilitySize {
                    RawdeaProjectAvatar(name: row.project.name, tintSeed: row.project.id)
                }

                VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                    Text(row.project.name)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.accent)
                    Text(row.project.stage.title)
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                    Text(row.summary)
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    if dynamicTypeSize.isAccessibilitySize {
                        status
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !dynamicTypeSize.isAccessibilitySize {
                    status
                }
            }
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(
            "\(row.project.name), \(row.project.stage.title). \(row.summary)"
        )
        .accessibilityValue(row.newCount > 0 ? "\(row.newCountText) new" : "Caught up")
    }

    @ViewBuilder
    private var status: some View {
        if row.newCount > 0 {
            Text("\(row.newCountText) new")
                .font(RawdeaTypography.metadata.weight(.semibold))
                .foregroundStyle(RawdeaPalette.primaryText)
        }
    }
}
