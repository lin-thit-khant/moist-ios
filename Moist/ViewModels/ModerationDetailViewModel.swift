//
//  ModerationDetailViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class ModerationDetailViewModel: ObservableObject {

    @Published private(set) var report: ModerationReportDetail?
    @Published private(set) var history: [ModerationReviewEvent] = []

    @Published private(set) var viewerId: UUID?

    @Published private(set) var isLoading = false
    @Published private(set) var isUpdating = false

    @Published private(set) var errorMessage: String?

    private let service: ModerationService

    init(
        service: ModerationService = ModerationService()
    ) {
        self.service = service
    }

    // MARK: - Load Report and Audit History

    func load(reportId: UUID) async {

        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {

            // The server authorizes both reads.
            // Do not hydrate evidence using
            // the normal feed or profile services.

            async let reportResult = service.fetchReport(
                reportId: reportId
            )

            async let historyResult = service.fetchHistory(
                reportId: reportId
            )

            async let viewerResult = service.currentUserId()

            let loadedReport = try await reportResult
            let loadedHistory = try await historyResult
            let loadedViewer = try await viewerResult

            try Task.checkCancellation()

            report = loadedReport
            history = loadedHistory
            viewerId = loadedViewer

        } catch is CancellationError {
            return

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Review Actions

    @discardableResult
    func perform(
        reportId: UUID,
        action: ModerationAction,
        note: String? = nil
    ) async -> Bool {

        guard !isUpdating,
              !isLoading else {
            return false
        }

        isUpdating = true
        errorMessage = nil

        defer {
            isUpdating = false
        }

        do {

            _ = try await service.performAction(
                reportId: reportId,
                action: action,
                note: note
            )

            await load(reportId: reportId)

            return errorMessage == nil

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Ownership of Review

    var isCurrentReviewer: Bool {

        guard let report,
              let viewerId else {
            return false
        }

        return report.status == "reviewing"
            && report.reviewerId == viewerId
    }

    func clearError() {
        errorMessage = nil
    }
}
