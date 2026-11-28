//
//  ContributorViewModels.swift
//  Rawdea
//

import Foundation
import Combine

/// The owner's Contributors sheet.
@MainActor
final class ContributorsViewModel: ObservableObject {

    @Published private(set) var members: [ProjectMember] = []
    @Published private(set) var candidates: [ContributorCandidate] = []
    @Published private(set) var hasLoaded = false
    @Published private(set) var busyId: UUID?
    @Published private(set) var errorMessage: String?

    let projectId: UUID
    private let service: ContributorServicing

    init(projectId: UUID, service: ContributorServicing? = nil) {
        self.projectId = projectId
        self.service = service ?? CollaborationService()
    }

    /// Invited and active people, active first.
    var places: [ProjectMember] {
        members.filter(\.holdsPlace).sorted {
            $0.status == .active && $1.status != .active
        }
    }

    var isFull: Bool {
        places.count >= ProjectMember.limit
    }

    func load() async {
        errorMessage = nil
        do {
            let loaded = try await service.fetchMembers(projectId: projectId)
            let approved = try await service
                .fetchApprovedSuggestions(projectId: projectId)
            members = loaded
            candidates = ContributorCandidate.from(
                approved: approved,
                members: loaded
            )
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = CollaborationErrorMessage.from(error)
        }
    }

    func invite(userId: UUID) async {
        await act(on: userId) {
            try await $0.invite(projectId: self.projectId, userId: userId)
        }
    }

    func remove(userId: UUID, hidePosts: Bool) async {
        await act(on: userId) {
            try await $0.remove(
                projectId: self.projectId,
                userId: userId,
                hidePosts: hidePosts
            )
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func act(
        on userId: UUID,
        _ action: (ContributorServicing) async throws -> Void
    ) async {
        guard busyId == nil else { return }
        busyId = userId
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

/// The viewer's own place in someone's Project.
@MainActor
final class MembershipViewModel: ObservableObject {

    @Published private(set) var membership: ProjectMember?
    @Published private(set) var hasLoaded = false
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?

    let projectId: UUID
    private let service: ContributorServicing

    init(projectId: UUID, service: ContributorServicing? = nil) {
        self.projectId = projectId
        self.service = service ?? CollaborationService()
    }

    var status: MemberStatus? {
        membership?.status
    }

    func load() async {
        do {
            membership = try await service
                .fetchMyMembership(projectId: projectId)
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = CollaborationErrorMessage.from(error)
        }
    }

    /// True once the server accepted the answer.
    func respond(accept: Bool) async -> Bool {
        await act { try await $0.respond(projectId: self.projectId, accept: accept) }
    }

    func leave() async -> Bool {
        await act { try await $0.leave(projectId: self.projectId) }
    }

    func clearError() {
        errorMessage = nil
    }

    private func act(
        _ action: (ContributorServicing) async throws -> Void
    ) async -> Bool {
        guard !isUpdating else { return false }
        isUpdating = true
        errorMessage = nil
        defer { isUpdating = false }

        do {
            try await action(service)
            await load()
            return true
        } catch {
            let message = CollaborationErrorMessage.from(error)
            await load()
            errorMessage = message
            return false
        }
    }
}
