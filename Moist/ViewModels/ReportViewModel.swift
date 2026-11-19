//
//  ReportViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class ReportViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var isSubmitting = false
    @Published private(set) var hasSubmitted = false
    @Published private(set) var errorMessage: String?

    // MARK: - Service

    private let service: ReportService

    init(
        service: ReportService = ReportService()
    ) {
        self.service = service
    }

    // MARK: - Submit

    func submit(
        target: ReportTarget,
        reason: ReportReason,
        explanation: String
    ) async {

        guard !isSubmitting, !hasSubmitted else {
            return
        }

        let cleaned = explanation.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleaned.count <= 1000 else {
            errorMessage =
                "Your explanation cannot exceed 1,000 characters."
            return
        }

        if reason == .other && cleaned.isEmpty {
            errorMessage =
                "Please explain what you are reporting."
            return
        }

        isSubmitting = true
        errorMessage = nil

        defer {
            isSubmitting = false
        }

        do {

            _ = try await service.submitReport(
                target: target,
                reason: reason,
                explanation: cleaned
            )

            hasSubmitted = true

        } catch is CancellationError {
            return

        } catch {

            errorMessage = readableError(error)
        }
    }

    // MARK: - Error Messages

    private func readableError(
        _ error: Error
    ) -> String {

        let message = error.localizedDescription.lowercased()

        if message.contains("already reported") {
            return "You have already reported this item."
        }

        if message.contains("report limit reached") ||
           message.contains("daily report limit reached") {

            return """
            You've reached the reporting limit.
            Please try again later.
            """
        }

        if message.contains("not available for reporting") {
            return """
            This item cannot be reported.
            It may have been removed or is no longer accessible.
            """
        }

        if message.contains("authentication required") {
            return "Please sign in to submit a report."
        }

        if message.contains("report explanation is too long") {
            return "Your explanation is too long."
        }

        if message.contains("please explain your report") {
            return "Please explain what you are reporting."
        }

        return """
        Your report couldn't be submitted.
        Please check your connection and try again.
        """
    }

    func clearError() {
        errorMessage = nil
    }
}
