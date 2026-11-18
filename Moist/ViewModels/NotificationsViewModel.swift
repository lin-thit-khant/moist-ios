//
//  NotificationsViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {

    // MARK: - Data

    @Published private(set) var notifications:
        [RawdeaNotification] = []

    @Published private(set) var unreadCount = 0

    // MARK: - Loading State

    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    @Published private(set) var isMarkingAll = false

    @Published private(set) var updatingIds: Set<UUID> = []

    // MARK: - Errors

    @Published private(set) var errorMessage: String?
    @Published private(set) var actionErrorMessage: String?

    private let service: NotificationService

    init(
        service: NotificationService = NotificationService()
    ) {
        self.service = service
    }

    
    // MARK: - Revalidate Notifications

    func reloadVisibleNotifications() async {

        guard !isLoading,
              !isMarkingAll,
              updatingIds.isEmpty else {
            return
        }

        notifications = []
        unreadCount = 0
        hasLoaded = false

        await loadNotifications()
    }

    // MARK: - Fetch Notifications

    func loadNotifications() async {

        guard !isLoading,
              !isMarkingAll,
              updatingIds.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            let loaded = try await service
                .fetchNotifications()

            let count = try await service
                .fetchUnreadCount()

            try Task.checkCancellation()

            notifications = loaded
            unreadCount = count

            hasLoaded = true

        } catch is CancellationError {
            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh Badge Count

    func refreshUnreadCount() async {

        do {

            let count = try await service
                .fetchUnreadCount()

            try Task.checkCancellation()

            unreadCount = count

        } catch is CancellationError {
            return

        } catch {

            // Do not destroy an existing badge
            // count because one refresh failed.
        }
    }

    // MARK: - Mark One as Read

    func markAsRead(
        notificationId: UUID
    ) async {

        guard !isLoading,
              !isMarkingAll,
              !updatingIds.contains(notificationId),
              let existing = notifications.first(
                where: { $0.id == notificationId }
              ),
              !existing.isRead else {
            return
        }

        updatingIds.insert(notificationId)
        actionErrorMessage = nil

        defer {
            updatingIds.remove(notificationId)
        }

        do {

            try await service.markAsRead(
                notificationId: notificationId
            )

            if let index = notifications.firstIndex(
                where: { $0.id == notificationId }
            ) {

                notifications[index].isRead = true
            }

            unreadCount = max(0, unreadCount - 1)

        } catch {

            actionErrorMessage = error.localizedDescription
        }
    }

    // MARK: - Mark All as Read

    func markAllAsRead() async {

        guard !isLoading,
              !isMarkingAll,
              updatingIds.isEmpty,
              unreadCount > 0 else {
            return
        }

        isMarkingAll = true
        actionErrorMessage = nil

        defer {
            isMarkingAll = false
        }

        do {

            try await service.markAllAsRead()

            // Database update succeeded.
            // Update visible rows immediately.

            for index in notifications.indices {
                notifications[index].isRead = true
            }

            unreadCount = 0

            // Recheck for events that arrived
            // around the same time as the update.

            unreadCount = try await service
                .fetchUnreadCount()

        } catch {

            actionErrorMessage = error.localizedDescription
        }
    }

    func clearActionError() {
        actionErrorMessage = nil
    }
}
