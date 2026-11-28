//
//  ContributorInviteView.swift
//  Rawdea
//

import SwiftUI

/// An invitation to contribute, to accept or decline.
struct ContributorInviteView: View {

    let projectId: UUID

    @StateObject private var viewModel: MembershipViewModel
    @State private var project: Project?
    @State private var ownerName: String?
    @State private var isUnavailable = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    init(projectId: UUID) {
        self.projectId = projectId
        _viewModel = StateObject(
            wrappedValue: MembershipViewModel(projectId: projectId)
        )
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: RawdeaSpacing.md) {

                if let project, viewModel.hasLoaded {
                    content(project)
                } else if isUnavailable {
                    RawdeaEmptyState(
                        symbol: "folder",
                        title: "Invitation unavailable",
                        message: "This Project is no longer available."
                    )
                } else {
                    RawdeaLoadingIndicator("Loading invitation...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RawdeaSpacing.xl)
                }

                if let error = viewModel.errorMessage {
                    RawdeaInlineError(message: error)
                }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
            .padding(.vertical, RawdeaSpacing.md)
        }
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .navigationTitle("Invitation")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ project: Project) -> some View {

        switch viewModel.status {

        case .invited:

            RawdeaNote(
                title: "Contribute to \(project.name)",
                message: "\(ownerName ?? "The owner") invited you to post in this Project."
            ) {
                RawdeaNoteDetail("You can post notes, questions and progress under your name. Decisions and stages stay with the owner.")
                RawdeaNoteDetail("Accepting also follows the Project. You can leave any time.")
            }

            RawdeaWrapLayout(spacing: RawdeaSpacing.xs) {
                RawdeaPillButton(
                    title: "Accept",
                    isPrimary: true,
                    isWorking: viewModel.isUpdating
                ) {
                    Task {
                        if await viewModel.respond(accept: true) {
                            openPostRoute?(.project(projectId))
                        }
                    }
                }
                RawdeaPillButton(title: "Decline") {
                    Task {
                        if await viewModel.respond(accept: false) {
                            dismiss()
                        }
                    }
                }
            }
            .disabled(viewModel.isUpdating)

        case .active:

            RawdeaNote(
                title: "You contribute to \(project.name)",
                message: "Write from the Project page."
            ) {
                RawdeaPillButton(title: "Open Project") {
                    openPostRoute?(.project(projectId))
                }
            }

        default:

            RawdeaNote(
                title: project.name,
                message: "This invitation is no longer open."
            ) {
                RawdeaPillButton(title: "Open Project") {
                    openPostRoute?(.project(projectId))
                }
            }
        }
    }

    private func load() async {
        await viewModel.load()
        do {
            let loaded = try await ProjectService().fetchProject(id: projectId)
            project = loaded
            ownerName = try? await ProfileService()
                .fetchProfile(userId: loaded.userId)
                .username
        } catch is CancellationError {
            return
        } catch {
            isUnavailable = true
        }
    }
}
