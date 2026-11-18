//
//  UserBlockViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 18/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class UserBlockViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var isBlocked = false
    @Published private(set) var hasChecked = false

    @Published private(set) var isChecking = false
    @Published private(set) var isUpdating = false

    @Published private(set) var errorMessage: String?

    // MARK: - Service

    private let service: BlockService

    init(
        service: BlockService = BlockService()
    ) {
        self.service = service
    }

    // MARK: - Load Status

    func loadStatus(userId: UUID) async {

        guard !isChecking, !isUpdating else {
            return
        }

        isChecking = true
        hasChecked = false
        errorMessage = nil

        defer {
            isChecking = false
        }

        do {

            isBlocked = try await service.isBlocked(
                userId: userId
            )

            hasChecked = true

        } catch is CancellationError {
            return

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Block

    @discardableResult
    func block(userId: UUID) async -> Bool {

        guard hasChecked,
              !isBlocked,
              !isUpdating,
              !isChecking else {
            return false
        }

        isUpdating = true
        errorMessage = nil

        defer {
            isUpdating = false
        }

        do {

            try await service.blockUser(
                userId: userId
            )

            isBlocked = true

            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Unblock

    @discardableResult
    func unblock(userId: UUID) async -> Bool {

        guard hasChecked,
              isBlocked,
              !isUpdating,
              !isChecking else {
            return false
        }

        isUpdating = true
        errorMessage = nil

        defer {
            isUpdating = false
        }

        do {

            try await service.unblockUser(
                userId: userId
            )

            isBlocked = false

            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
