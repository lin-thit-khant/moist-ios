//
//  DiscoveryView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import SwiftUI

private struct DiscoverySearchKey: Hashable {

    let query: String
    let category: DiscoveryCategory
}

struct DiscoveryView: View {

    @StateObject private var viewModel =
        DiscoveryViewModel()

    @State private var searchText = ""

    @State private var selectedCategory:
        DiscoveryCategory = .projects

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    // MARK: - Search state

    private var cleanedQuery: String {

        searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var searchKey: DiscoverySearchKey {

        DiscoverySearchKey(
            query: cleanedQuery,
            category: selectedCategory
        )
    }

    private var resultsAreCurrent: Bool {

        viewModel.currentQuery == cleanedQuery &&
        viewModel.currentCategory == selectedCategory
    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

            if cleanedQuery.count < 2 {

                ExploreHomeSections()

            } else {

                categorySelector

                Divider()
                    .overlay(RawdeaPalette.divider)

                resultsList
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.large)

        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(
                displayMode: .always
            ),
            prompt: "Search Projects and people"
        )

        // MARK: - Debounced search

        .task(id: searchKey) {

            let query = cleanedQuery
            let category = selectedCategory

            guard query.count >= 2 else {

                viewModel.clear()
                return
            }

            do {

                try await Task.sleep(
                    for: .milliseconds(350)
                )

            } catch {

                return
            }

            guard !Task.isCancelled else {
                return
            }

            await viewModel.search(
                query: query,
                category: category
            )
        }

        // Revalidate results when returning
        // from another destination.

        .onAppear {

            guard cleanedQuery.count >= 2,
                  viewModel.hasSearched else {
                return
            }

            Task {

                await refreshSearch()
            }
        }

        // Revalidate after foregrounding.

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active,
                  cleanedQuery.count >= 2 else {
                return
            }

            Task {

                await refreshSearch()
            }
        }
    }

    // MARK: - Search category selector

    @ViewBuilder
    private var categorySelector: some View {

        if dynamicTypeSize.isAccessibilitySize {

            // A menu avoids cramped segmented
            // labels at very large text sizes.

            HStack {

                Text("Search category")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

                Spacer(minLength: 0)

                categoryPicker
                    .pickerStyle(.menu)
            }
            .padding(
                .horizontal,
                RawdeaSpacing.screenInset
            )
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )

        } else {

            categoryPicker
                .pickerStyle(.segmented)
                .padding(
                    .horizontal,
                    RawdeaSpacing.screenInset
                )
                .padding(
                    .vertical,
                    RawdeaSpacing.sm
                )
        }
    }

    private var categoryPicker: some View {

        Picker(
            "Search category",
            selection: $selectedCategory
        ) {

            ForEach(DiscoveryCategory.allCases) {
                category in

                Text(category.title)
                    .tag(category)
            }
        }
    }

    // MARK: - Results list

    private var resultsList: some View {

        List {

            if !resultsAreCurrent ||
                      viewModel.isLoading ||
                      !viewModel.hasSearched {

                RawdeaLoadingIndicator("Searching...")
                    .frame(maxWidth: .infinity)
                    .padding(
                        .vertical,
                        RawdeaSpacing.xl
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

            } else if let error =
                viewModel.errorMessage {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't search Rawdea",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {

                        await refreshSearch()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else {

                if viewModel.isCurrentResultEmpty {

                    RawdeaEmptyState(
                        symbol: "magnifyingglass",
                        title: "No results found",
                        message:
                            viewModel.hasMore
                            ? "No visible results on this page. Load more to continue searching."
                            : "Try another search term or choose a different category."
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

                } else {

                    categoryResults
                }

                paginationControls
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .scrollDismissesKeyboard(.interactively)

        .rawdeaRefreshable {

            await refreshSearch()
        }
    }

    // MARK: - Category results

    @ViewBuilder
    private var categoryResults: some View {

        switch selectedCategory {

        case .people:

            ForEach(viewModel.people) { profile in

                personRow(profile)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
            }

        case .projects:

            ForEach(viewModel.projects) { project in

                projectRow(project)
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
            }

        case .posts:

            ForEach(viewModel.posts) { post in

                VStack(spacing: 0) {

                    PostRowView(post: post)

                    Divider()
                        .overlay(
                            RawdeaPalette.divider
                        )
                        .padding(
                            .horizontal,
                            RawdeaSpacing.screenInset
                        )
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }
        }
    }

    // MARK: - People result

    private func displayName(for profile: Profile) -> String {
        let name = profile.displayname.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? profile.username : name
    }

    private func personRow(
        _ profile: Profile
    ) -> some View {

        NavigationLink(
            value: RawdeaPostRoute.author(
                profile.id
            )
        ) {

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.sm
            ) {

                RawdeaInitialAvatar(name: displayName(for: profile))

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xxs
                ) {

                    Text(displayName(for: profile))
                    .font(
                        RawdeaTypography.authorName
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )

                    Text("@\(profile.username)")
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.8)

                    if !profile.bio.isEmpty {

                        Text(profile.bio)
                            .font(
                                RawdeaTypography.secondary
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                            .lineLimit(2)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .padding(
                .vertical,
                RawdeaSpacing.xs
            )
            .contentShape(Rectangle())
        }
        .accessibilityHint("Opens profile")
    }

    // MARK: - Project result

    private func projectRow(
        _ project: Project
    ) -> some View {

        NavigationLink(
            value: RawdeaPostRoute.project(
                project.id
            )
        ) {

            RawdeaProjectSurface {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaProjectCard(
                        project: project
                    )

                }
                .frame(
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget,
                    alignment: .leading
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Project")
        .padding(
            .vertical,
            RawdeaSpacing.xxs
        )
    }

    // MARK: - Pagination

    @ViewBuilder
    private var paginationControls: some View {

        if let error =
            viewModel.paginationErrorMessage {

            RawdeaInlineError(
                message:
                    "Couldn't load more results. \(error)"
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }

        if viewModel.hasMore {

            HStack {

                Spacer(minLength: 0)

                if viewModel.isLoadingMore {

                    RawdeaLoadingIndicator("Loading more...")

                } else {

                    Button(
                        viewModel.paginationErrorMessage == nil
                        ? "Load More"
                        : "Retry Loading More"
                    ) {

                        Task {

                            await viewModel.loadMore()
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(
                .vertical,
                RawdeaSpacing.sm
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Refresh

    @MainActor
    private func refreshSearch() async {

        guard cleanedQuery.count >= 2 else {
            return
        }

        await viewModel.search(
            query: cleanedQuery,
            category: selectedCategory
        )
    }
}
