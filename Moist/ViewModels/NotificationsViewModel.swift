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

    /// Results of the signed-in person's held posts.
    @Published private(set) var heldNotices: [HeldPostNotice] = []

    /// The held post whose second look is being sent.
    @Published private(set) var askingId: UUID?

    // MARK: - Loading

    @Published private(set) var isLoading = false

    @Published private(set) var hasLoaded = false

    @Published private(set) var isMarkingAll = false

    @Published private(set) var updatingIds:
        Set<UUID> = []

    // MARK: - Errors

    @Published private(set) var errorMessage: String?

    @Published private(set) var actionErrorMessage: String?

    private let service: NotificationService
    private let heldPostService: HeldPostService

    // Identifies the latest badge request.
    private var badgeRequestID = UUID()

    init(
        service: NotificationService =
            NotificationService(),
        heldPostService: HeldPostService? =
            nil
    ) {

        self.service = service
        self.heldPostService = heldPostService ?? HeldPostService()
    }

    private var isBusy: Bool {

        isLoading ||
        isMarkingAll ||
        !updatingIds.isEmpty
    }

    // MARK: - Revalidate notifications

    func reloadVisibleNotifications() async {

        guard !isBusy else {
            return
        }

        // Clear potentially outdated rows before
        // checking their current visibility.

        notifications = []
        heldNotices = []
        hasLoaded = false

        // Do not set unreadCount to zero here.
        // Keep the last confirmed badge value.

        await loadNotifications()
    }

    // MARK: - Load notifications

    func loadNotifications() async {

        guard !isBusy else {
            return
        }

        isLoading = true
        errorMessage = nil

        // Invalidate any older badge request.
        badgeRequestID = UUID()

        defer {

            isLoading = false
        }

        do {

            let loaded = try await service
                .fetchNotifications()

            // A server without hold-for-review still shows Activity.
            let held = (try? await heldPostService.fetchMine()) ?? []

            try Task.checkCancellation()

            notifications = loaded
            heldNotices = held
            hasLoaded = true

            // Results on screen count as read.
            if held.contains(where: { !$0.seen }) {
                try? await heldPostService.markSeen()
            }

            await updateUnreadCount()

        } catch is CancellationError {

            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - External badge refresh

    func refreshUnreadCount() async {

        guard !isBusy else {
            // The active operation will perform
            // its own badge refresh.
            return
        }

        await updateUnreadCount()
    }

    // MARK: - Latest count wins

    private func updateUnreadCount() async {

        let requestID = UUID()

        badgeRequestID = requestID

        do {

            var count = try await service
                .fetchUnreadCount()

            let held = (try? await heldPostService.fetchMine()) ?? []
            count += held.filter { !$0.seen }.count

            try Task.checkCancellation()

            guard badgeRequestID == requestID else {
                return
            }

            unreadCount = count

        } catch {

            // A failed count refresh must not
            // erase the last confirmed count.
        }
    }

    // MARK: - Mark one as read

    @discardableResult
    func markAsRead(
        notificationId: UUID
    ) async -> Bool {

        guard !isBusy,
              let existing = notifications.first(
                where: {
                    $0.id == notificationId
                }
              ) else {

            return false
        }

        actionErrorMessage = nil

        if existing.isRead {

            return true
        }

        updatingIds.insert(notificationId)

        // Older badge results are no longer valid.
        badgeRequestID = UUID()

        defer {

            updatingIds.remove(notificationId)
        }

        do {

            try await service.markAsRead(
                notificationId: notificationId
            )

            if let index =
                notifications.firstIndex(
                    where: {
                        $0.id == notificationId
                    }
                ) {

                notifications[index].isRead = true
            }

            // Update immediately after the
            // successful database mutation.

            unreadCount = max(
                0,
                unreadCount - 1
            )

            // Reconcile with the server, including
            // notifications that may have arrived.

            await updateUnreadCount()

            return true

        } catch {

            actionErrorMessage =
                error.localizedDescription

            return false
        }
    }

    // MARK: - Mark all as read

    func markAllAsRead() async {

        guard !isBusy,
              unreadCount > 0 ||
              notifications.contains(
                where: { !$0.isRead }
              ) else {

            return
        }

        isMarkingAll = true
        actionErrorMessage = nil

        badgeRequestID = UUID()

        defer {

            isMarkingAll = false
        }

        do {

            try await service.markAllAsRead()

            for index in notifications.indices {

                notifications[index].isRead = true
            }

            unreadCount = 0

            // Reconcile with newly arrived
            // notifications after marking all read.

            await updateUnreadCount()

        } catch {

            actionErrorMessage =
                error.localizedDescription
        }
    }

    // MARK: - Second look

    func askForSecondLook(id: UUID) async {

        guard askingId == nil else {
            return
        }

        askingId = id
        actionErrorMessage = nil

        defer {

            askingId = nil
        }

        do {

            try await heldPostService.askForSecondLook(id: id)

            heldNotices = try await heldPostService.fetchMine()

        } catch {

            actionErrorMessage =
                error.localizedDescription
        }
    }

    func clearActionError() {

        actionErrorMessage = nil
    }
}
