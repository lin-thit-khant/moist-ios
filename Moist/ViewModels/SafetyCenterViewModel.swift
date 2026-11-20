//
//  SafetyCenterViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class SafetyCenterViewModel: ObservableObject {

    @Published private(set) var requests: [SafetyRequest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?

    private let service: SafetyService

    init(service: SafetyService = SafetyService()) {
        self.service = service
    }

    func load() async {

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            requests = try await service.myRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submit(
        kind: SafetyRequestKind,
        message: String
    ) async -> Bool {

        guard !isSubmitting else { return false }

        let cleaned = message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard (20...2000).contains(cleaned.count) else {
            errorMessage = "Enter 20 to 2000 characters."
            return false
        }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        defer { isSubmitting = false }

        do {

            _ = try await service.submit(
                kind: kind,
                message: cleaned
            )

            successMessage = "Your request was submitted."

            // Fetch updated status from the server.

            await load()

            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
