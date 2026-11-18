//
//  BlockedUsersViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 18/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class BlockedUsersViewModel: ObservableObject {

    @Published private(set) var users: [BlockedUser] = []

    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    @Published private(set) var unblockingUserId: UUID?

    @Published private(set) var errorMessage: String?

    private let service: BlockService

    init(
        service: BlockService = BlockService()
    ) {
        self.service = service
    }

    // MARK: - Load Blocked Users

    func loadUsers() async {

        guard !isLoading,
              unblockingUserId == nil else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let loaded = try await service
                .fetchBlockedUsers()

            try Task.checkCancellation()

            users = loaded
            hasLoaded = true

        } catch is CancellationError {
            return

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Unblock From List

    func unblockUser(
        userId: UUID
    ) async {

        guard unblockingUserId == nil,
              !isLoading else {
            return
        }

        unblockingUserId = userId
        errorMessage = nil

        defer {
            unblockingUserId = nil
        }

        do {

            try await service.unblockUser(
                userId: userId
            )

            users.removeAll {
                $0.blockedId == userId
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
