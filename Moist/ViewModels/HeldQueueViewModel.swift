//
//  HeldQueueViewModel.swift
//  Rawdea
//

import Foundation
import Combine

@MainActor
final class HeldQueueViewModel: ObservableObject {

    @Published private(set) var items: [HeldQueueItem] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var decidingId: UUID?
    @Published private(set) var errorMessage: String?

    private let service: HeldPostService

    init(service: HeldPostService? = nil) {
        self.service = service ?? HeldPostService()
    }

    func load() async {
        errorMessage = nil
        do {
            items = try await service.fetchQueue()
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    func decide(_ item: HeldQueueItem, approve: Bool) async {
        guard decidingId == nil else { return }

        decidingId = item.id
        errorMessage = nil
        defer { decidingId = nil }

        do {
            try await service.decide(id: item.id, approve: approve)
            items.removeAll { $0.id == item.id }
        } catch {
            let message = PublicationErrorMessage.from(error)
            // Someone else may have decided it already.
            await load()
            errorMessage = message
        }
    }
}
