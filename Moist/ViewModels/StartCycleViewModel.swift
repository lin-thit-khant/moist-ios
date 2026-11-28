//
//  StartCycleViewModel.swift
//  Rawdea
//

import Foundation
import Combine

protocol CycleServicing {
    func startCycle(
        projectId: UUID,
        note: String,
        name: String,
        stage: ProjectStage
    ) async throws -> Project
}

extension ProjectService: CycleServicing {}

@MainActor
final class StartCycleViewModel: ObservableObject {

    @Published var name = ""
    @Published var stage = ProjectStage.inProgress
    @Published var note = ""

    @Published private(set) var isStarting = false
    @Published private(set) var errorMessage: String?
    /// Set once the server has started the cycle.
    @Published private(set) var started: Project?

    static let stages: [ProjectStage] = [.early, .inProgress]

    private let service: CycleServicing

    init(service: CycleServicing? = nil) {
        self.service = service ?? ProjectService()
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canStart: Bool {
        !isStarting &&
        started == nil &&
        RawdeaPostDraft(content: note).isValid &&
        RawdeaTextLength.count(trimmedName) <= ProjectCycle.nameLimit
    }

    func start(projectId: UUID) async {
        guard canStart else { return }

        isStarting = true
        errorMessage = nil
        defer { isStarting = false }

        do {
            started = try await service.startCycle(
                projectId: projectId,
                note: RawdeaPostDraft(content: note).trimmedContent,
                name: trimmedName,
                stage: stage
            )
        } catch {
            errorMessage = CollaborationErrorMessage.from(error)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
