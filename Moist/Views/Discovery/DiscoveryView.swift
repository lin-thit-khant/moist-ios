//
//  DiscoveryView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import SwiftUI

// MARK: - Search Task Identity

private struct DiscoverySearchKey: Hashable {

    let query: String
    let category: DiscoveryCategory
}

// MARK: - Discovery View

struct DiscoveryView: View {

    @StateObject private var viewModel =
        DiscoveryViewModel()

    @State private var searchText = ""

    @State private var selectedCategory:
        DiscoveryCategory = .people

    // MARK: - Search State

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

            // MARK: - Category Selector

            Picker(
                "Search Category",
                selection: $selectedCategory
            ) {

                ForEach(DiscoveryCategory.allCases) {
                    category in

                    Text(category.title)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // MARK: - Search Results

            List {

                if cleanedQuery.count < 2 {

                    ContentUnavailableView(
                        "Explore Rawdea",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Enter at least two characters to search people, Projects, or posts."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)

                } else if !resultsAreCurrent ||
                          viewModel.isLoading ||
                          !viewModel.hasSearched {

                    HStack(spacing: 12) {

                        ProgressView()

                        Text("Searching...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .listRowSeparator(.hidden)

                } else if let error = viewModel.errorMessage {

                    searchError(error)

                } else if viewModel.isCurrentResultEmpty {

                    emptyResults

                } else {

                    // MARK: - Category Results

                    switch selectedCategory {

                    case .people:

                        ForEach(viewModel.people) {
                            profile in

                            personRow(profile)
                        }

                    case .projects:

                        ForEach(viewModel.projects) {
                            project in

                            projectRow(project)
                        }

                    case .posts:

                        ForEach(viewModel.posts) {
                            post in

                            PostRowView(post: post)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: 0,
                                        leading: 0,
                                        bottom: 0,
                                        trailing: 0
                                    )
                                )
                                .listRowSeparator(.hidden)
                        }
                    }

                    // MARK: - Loaded Count

                    Text(
                        "\(viewModel.currentResultCount) results loaded"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)

                    // MARK: - Pagination Error

                    if let error =
                        viewModel.paginationErrorMessage {

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {

                            Text(
                                "Couldn't load more results"
                            )
                            .font(.subheadline)
                            .fontWeight(.medium)

                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .listRowSeparator(.hidden)
                    }

                    // MARK: - Load More

                    if viewModel.hasMore {

                        HStack {

                            Spacer()

                            if viewModel.isLoadingMore {

                                ProgressView(
                                    "Loading more..."
                                )

                            } else {

                                Button("Load More") {

                                    Task {

                                        await viewModel
                                            .loadMore()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)

            .refreshable {

                guard cleanedQuery.count >= 2 else {
                    return
                }

                await viewModel.search(
                    query: cleanedQuery,
                    category: selectedCategory
                )
            }
        }

        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)

        // Native iOS search field.

        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(
                displayMode: .always
            ),
            prompt: "Search Rawdea"
        )

        // MARK: - Debounced Search

        .task(id: searchKey) {

            let query = cleanedQuery
            let category = selectedCategory

            guard query.count >= 2 else {

                viewModel.clear()
                return
            }

            // Delay requests slightly while
            // the user is typing.

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
    }

    // MARK: - People Result

    private func personRow(
        _ profile: Profile
    ) -> some View {

        NavigationLink {

            AuthorProfileView(
                userId: profile.id
            )

        } label: {

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                Image(
                    systemName: "person.crop.circle.fill"
                )
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(
                        profile.displayname.isEmpty
                        ? profile.username
                        : profile.displayname
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)

                    Text("@\(profile.username)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !profile.bio.isEmpty {

                        Text(profile.bio)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Project Result

    private func projectRow(
        _ project: Project
    ) -> some View {

        NavigationLink {

            ProjectRouteView(
                projectId: project.id
            )

        } label: {

            HStack(spacing: 12) {

                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 38)

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Public Project")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Empty Results

    private var emptyResults: some View {

        ContentUnavailableView.search(
            text: cleanedQuery
        )
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
    }

    // MARK: - Error State

    private func searchError(
        _ message: String
    ) -> some View {

        VStack(spacing: 12) {

            Image(
                systemName: "exclamationmark.circle"
            )
            .font(.largeTitle)
            .foregroundStyle(.secondary)

            Text("Couldn't search Rawdea")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {

                Task {

                    await viewModel.search(
                        query: cleanedQuery,
                        category: selectedCategory
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .listRowSeparator(.hidden)
    }
}
