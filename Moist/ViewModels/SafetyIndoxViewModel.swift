//
//  SafetyIndoxViewModel.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import Foundation
import Combine

@MainActor
final class SafetyInboxViewModel: ObservableObject {

    @Published private(set) var requests:
        [ModerationSafetyRequest] = []

    @Published private(set) var isLoading = false
    @Published private(set) var isResponding = false
    @Published private(set) var errorMessage: String?

    private let service: SafetyService

    init(service: SafetyService = SafetyService()) {
        self.service = service
    }

    func load(status: SafetyInboxStatus) async {

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            requests = try await service.inbox(
                status: status
            )
        } catch {
            requests = []
            errorMessage = error.localizedDescription
        }
    }

    func resolve(
        requestId: UUID,
        response: String
    ) async -> Bool {

        guard !isResponding else { return false }

        let cleaned = response.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard (10...2000).contains(cleaned.count) else {
            errorMessage =
                "A response of 10 to 2000 characters is required."
            return false
        }

        isResponding = true
        errorMessage = nil

        defer { isResponding = false }

        do {
            try await service.respond(
                requestId: requestId,
                response: cleaned
            )

            return true

        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
