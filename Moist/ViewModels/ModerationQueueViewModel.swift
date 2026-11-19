//
//  ModerationQueueViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class ModerationQueueViewModel: ObservableObject {

    @Published var selectedStatus: ModerationStatus = .pending

    @Published private(set) var isAuthorized: Bool?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false

    @Published private(set) var reports: [ModerationQueueItem] = []
    @Published private(set) var hasMore = false

    @Published private(set) var errorMessage: String?

    private let service: ModerationService

    private var nextCursor: ModerationCursor?

    private let pageSize = 20

    init(
        service: ModerationService = ModerationService()
    ) {
        self.service = service
    }

    // MARK: - Authorization and Initial Load

    func prepare() async {

        if isAuthorized == nil {

            do {

                isAuthorized = try await service.isModerator()

            } catch is CancellationError {
                return

            } catch {

                errorMessage = error.localizedDescription
                return
            }
        }

        guard isAuthorized == true else {
            return
        }

        await reload()
    }

    func retryAuthorization() async {
        isAuthorized = nil
        errorMessage = nil
        await prepare()
    }

    // MARK: - Reload Queue

    func reload() async {

        guard isAuthorized == true,
              !isLoading,
              !isLoadingMore else {
            return
        }

        isLoading = true
        errorMessage = nil

        let requestedStatus = selectedStatus

        defer {
            isLoading = false
        }

        do {

            let results = try await service.fetchQueue(
                status: requestedStatus,
                after: nil,
                batchSize: pageSize + 1
            )

            try Task.checkCancellation()

            guard requestedStatus == selectedStatus else {
                return
            }

            let pageItems = Array(
                results.prefix(pageSize)
            )

            reports = pageItems

            nextCursor = pageItems.last?.cursor

            hasMore = results.count > pageSize

        } catch is CancellationError {
            return

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load More

    func loadMore() async {

        guard isAuthorized == true,
              hasMore,
              !isLoading,
              !isLoadingMore,
              let cursor = nextCursor else {
            return
        }

        isLoadingMore = true
        errorMessage = nil

        let requestedStatus = selectedStatus

        defer {
            isLoadingMore = false
        }

        do {

            let results = try await service.fetchQueue(
                status: requestedStatus,
                after: cursor,
                batchSize: pageSize + 1
            )

            try Task.checkCancellation()

            guard requestedStatus == selectedStatus else {
                return
            }

            let pageItems = Array(
                results.prefix(pageSize)
            )

            // Avoid accidentally repeating items.

            let existingIds = Set(
                reports.map(\.id)
            )

            reports.append(
                contentsOf: pageItems.filter {
                    !existingIds.contains($0.id)
                }
            )

            nextCursor = pageItems.last?.cursor

            hasMore = results.count > pageSize

        } catch is CancellationError {
            return

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
