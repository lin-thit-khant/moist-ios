//
//  SuggestionViewModels.swift
//  Rawdea
//

import Foundation
import Combine

/// Sends one suggestion.
@MainActor
final class SuggestUpdateViewModel: ObservableObject {

    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private let service: SuggestionServicing

    init(service: SuggestionServicing? = nil) {
        self.service = service ?? SuggestionService()
    }

    func send(projectId: UUID, kind: PostKind, content: String) async -> Bool {
        let draft = RawdeaPostDraft(content: content)
        guard !isSending, draft.isValid,
              ProjectSuggestion.kinds.contains(kind) else {
            return false
        }

        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await service.suggest(
                projectId: projectId,
                kind: kind,
                content: draft.trimmedContent
            )
            return true
        } catch {
            errorMessage = CollaborationErrorMessage.from(error)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

/// A list of suggestions: the owner's waiting ones, or your own.
@MainActor
final class SuggestionListViewModel: ObservableObject {

    enum Scope: Equatable {
        /// Waiting for the owner of this Project.
        case review(projectId: UUID)
        /// The viewer's own, optionally for one Project.
        case mine(projectId: UUID?)
    }

    @Published private(set) var suggestions: [ProjectSuggestion] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var busyId: UUID?
    @Published private(set) var errorMessage: String?

    let scope: Scope
    private let service: SuggestionServicing

    init(scope: Scope, service: SuggestionServicing? = nil) {
        self.scope = scope
        self.service = service ?? SuggestionService()
    }

    func load() async {
        errorMessage = nil
        do {
            switch scope {
            case .review(let projectId):
                suggestions = try await service.fetchWaiting(projectId: projectId)
            case .mine(let projectId):
                suggestions = try await service.fetchMine(projectId: projectId)
            }
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = CollaborationErrorMessage.from(error)
        }
    }

    func decide(_ suggestion: ProjectSuggestion, approve: Bool) async {
        await act(on: suggestion) {
            try await $0.decide(id: suggestion.id, approve: approve)
        }
    }

    func withdraw(_ suggestion: ProjectSuggestion) async {
        await act(on: suggestion) {
            try await $0.withdraw(id: suggestion.id)
        }
    }

    func block(_ suggestion: ProjectSuggestion) async {
        await act(on: suggestion) {
            try await $0.block(userId: suggestion.userId)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // The list changes only after the server accepts, then reloads.
    private func act(
        on suggestion: ProjectSuggestion,
        _ action: (SuggestionServicing) async throws -> Void
    ) async {
        guard busyId == nil else { return }
        busyId = suggestion.id
        errorMessage = nil
        defer { busyId = nil }

        do {
            try await action(service)
            await load()
        } catch {
            let message = CollaborationErrorMessage.from(error)
            await load()
            errorMessage = message
        }
    }
}
