//
//  DiscoveryViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class DiscoveryViewModel: ObservableObject {

    // MARK: - Search Results

    @Published private(set) var people: [Profile] = []
    @Published private(set) var projects: [Project] = []
    @Published private(set) var posts: [Post] = []

    // MARK: - Active Search

    @Published private(set) var currentQuery = ""
    @Published private(set) var currentCategory:
        DiscoveryCategory = .people

    @Published private(set) var hasSearched = false
    @Published private(set) var hasMore = false

    // MARK: - Loading

    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false

    // MARK: - Errors

    @Published private(set) var errorMessage: String?
    @Published private(set) var paginationErrorMessage: String?

    // MARK: - Internal State

    private let service: DiscoveryService

    private let pageSize = 20
    private var nextOffset = 0

    // Used to prevent stale network responses
    // from overwriting newer search results.

    private var requestID = UUID()

    init(
        service: DiscoveryService = DiscoveryService()
    ) {
        self.service = service
    }

    // MARK: - Reset

    func clear() {

        requestID = UUID()

        currentQuery = ""
        currentCategory = .people

        people = []
        projects = []
        posts = []

        hasSearched = false
        hasMore = false

        isLoading = false
        isLoadingMore = false

        errorMessage = nil
        paginationErrorMessage = nil

        nextOffset = 0
    }

    // MARK: - New Search

    func search(
        query: String,
        category: DiscoveryCategory
    ) async {

        let cleaned = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleaned.count >= 2 else {
            clear()
            return
        }

        let ticket = UUID()
        requestID = ticket

        currentQuery = cleaned
        currentCategory = category

        people = []
        projects = []
        posts = []

        nextOffset = 0
        hasMore = false
        hasSearched = false

        errorMessage = nil
        paginationErrorMessage = nil

        isLoading = true
        isLoadingMore = false
        
        defer {
            if requestID == ticket {
                isLoading = false
            }
        }

        do {

            try await fetchPage(
                query: cleaned,
                category: category,
                offset: 0,
                append: false,
                ticket: ticket
            )

            guard requestID == ticket else {
                return
            }

            hasSearched = true

        } catch is CancellationError {
            return

        } catch {

            guard requestID == ticket,
                  !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
            hasSearched = true
        }
    }

    // MARK: - Load More

    func loadMore() async {

        guard hasSearched,
              hasMore,
              !isLoading,
              !isLoadingMore else {
            return
        }

        let ticket = requestID

        let query = currentQuery
        let category = currentCategory
        let offset = nextOffset

        isLoadingMore = true
        paginationErrorMessage = nil

        defer {
            if requestID == ticket {
                isLoadingMore = false
            }
        }

        do {

            try await fetchPage(
                query: query,
                category: category,
                offset: offset,
                append: true,
                ticket: ticket
            )

        } catch is CancellationError {
            return

        } catch {

            guard requestID == ticket,
                  !Task.isCancelled else {
                return
            }

            paginationErrorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Fetch Page

    private func fetchPage(
        query: String,
        category: DiscoveryCategory,
        offset: Int,
        append: Bool,
        ticket: UUID
    ) async throws {

        switch category {

        case .people:

            let page = try await service.searchPeople(
                term: query,
                offset: offset,
                limit: pageSize
            )

            try Task.checkCancellation()

            guard requestID == ticket else {
                return
            }

            if append {

                let existingIDs = Set(
                    people.map(\.id)
                )

                people.append(
                    contentsOf: page.items.filter {
                        !existingIDs.contains($0.id)
                    }
                )

            } else {

                people = page.items
            }

            updatePagination(
                page,
                offset: offset
            )

        case .projects:

            let page = try await service.searchProjects(
                term: query,
                offset: offset,
                limit: pageSize
            )

            try Task.checkCancellation()

            guard requestID == ticket else {
                return
            }

            if append {

                let existingIDs = Set(
                    projects.map(\.id)
                )

                projects.append(
                    contentsOf: page.items.filter {
                        !existingIDs.contains($0.id)
                    }
                )

            } else {

                projects = page.items
            }

            updatePagination(
                page,
                offset: offset
            )

        case .posts:

            let page = try await service.searchPosts(
                term: query,
                offset: offset,
                limit: pageSize
            )

            try Task.checkCancellation()

            guard requestID == ticket else {
                return
            }

            if append {

                let existingIDs = Set(
                    posts.map(\.id)
                )

                posts.append(
                    contentsOf: page.items.filter {
                        !existingIDs.contains($0.id)
                    }
                )

            } else {

                posts = page.items
            }

            updatePagination(
                page,
                offset: offset
            )
        }
    }

    // MARK: - Pagination

    private func updatePagination<Item>(
        _ page: DiscoveryPage<Item>,
        offset: Int
    ) {

        nextOffset = offset + page.consumedCount
        hasMore = page.hasMore
    }

    // MARK: - Helpers

    var isCurrentResultEmpty: Bool {

        switch currentCategory {
        case .people:
            return people.isEmpty
        case .projects:
            return projects.isEmpty
        case .posts:
            return posts.isEmpty
        }
    }

    var currentResultCount: Int {

        switch currentCategory {
        case .people:
            return people.count
        case .projects:
            return projects.count
        case .posts:
            return posts.count
        }
    }
}
