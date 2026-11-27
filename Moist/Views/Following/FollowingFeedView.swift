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

    @AppStorage("rawdea.following.layout")
    private var layout = FollowingLayout.projects

    @Environment(\.rawdeaScrollingFeedHeader) private var scrollingHeader

    var body: some View {
        Group {
            // Without a followed Project there is only the feed.
            if viewModel.projectRows.isEmpty {
                postFeed
            } else {
                Group {
                    switch layout {
                    case .projects:
                        FollowedProjectList(
                            rows: viewModel.projectRows,
                            hasLoadError: viewModel.errorMessage != nil,
                            refresh: viewModel.refreshPosts
                        )
                    case .updates:
                        postFeed
                    }
                }
                // The switch scrolls as the list's first row.
                .environment(\.rawdeaScrollingFeedHeader, AnyView(header))
            }
        }
        .onAppear {
            Task { await viewModel.reloadVisiblePosts() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {

            scrollingHeader

            // Large text stacks the chips instead of clipping them.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: RawdeaSpacing.xs) { layoutChips }
                VStack(alignment: .leading, spacing: 0) { layoutChips }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
            .padding(.top, RawdeaSpacing.xs)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Following layout")
        }
    }

    private var layoutChips: some View {
        ForEach(FollowingLayout.allCases, id: \.self) { item in
            RawdeaChip(title: item.title, isSelected: layout == item) {
                layout = item
            }
        }
    }

    // Followed people's posts appear here.
    private var postFeed: some View {
        RawdeaHomeFeedList(
            posts: viewModel.posts,
            stageRows: viewModel.stageRows,
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

// MARK: - Layout

private enum FollowingLayout: String, CaseIterable {

    case projects
    case updates

    var title: String {
        switch self {
        case .projects: "Project list"
        case .updates: "Updates feed"
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

            RawdeaFeedEnd()
                .listRowSeparator(.hidden)
                .listRowBackground(RawdeaPalette.canvas)
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
                    RawdeaProjectAvatar(
                        name: row.project.name,
                        size: RawdeaSpacing.minimumTouchTarget
                    )
                }

                VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                    Text("\(Text(row.project.name).font(RawdeaTypography.authorName).foregroundStyle(RawdeaPalette.primaryText))  \(row.project.stage.title)")
                        .font(RawdeaTypography.secondary)
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
            HStack(spacing: RawdeaSpacing.xxs) {
                Circle()
                    .fill(RawdeaPalette.accent)
                    .frame(width: RawdeaSpacing.xs, height: RawdeaSpacing.xs)
                Text(row.newCountText)
                    .font(RawdeaTypography.metadata.weight(.semibold))
                    .foregroundStyle(RawdeaPalette.primaryText)
            }
        } else {
            Text("Caught up")
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
        }
    }
}
