//
//  ProjectContributorSection.swift
//  Rawdea
//

import SwiftUI

/// The Project header for a contributor or an invited person.
struct ProjectContributorSection: View {

    let project: Project

    @StateObject private var viewModel: MembershipViewModel
    @State private var isConfirmingLeave = false

    @Environment(\.rawdeaCreatePostInProject) private var createPostInProject
    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    init(project: Project) {
        self.project = project
        _viewModel = StateObject(
            wrappedValue: MembershipViewModel(projectId: project.id)
        )
    }

    var body: some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

            switch viewModel.status {

            case .invited:

                RawdeaPillButton(title: "View invitation", isPrimary: true) {
                    openPostRoute?(.invitation(project.id))
                }

            case .active:

                RawdeaNoteDetail(project.takesContributions
                    ? "You're a contributor."
                    : "You're a contributor. Posting is paused.")

                RawdeaWrapLayout(spacing: RawdeaSpacing.xs) {
                    if project.takesContributions, let createPostInProject {
                        RawdeaPillButton(title: "Write a post") {
                            createPostInProject(project)
                        }
                    }
                    RawdeaPillButton(
                        title: "Leave",
                        isWorking: viewModel.isUpdating
                    ) {
                        isConfirmingLeave = true
                    }
                    .disabled(viewModel.isUpdating)
                }

            default:

                EmptyView()
            }

            if let error = viewModel.errorMessage, viewModel.hasLoaded {
                RawdeaInlineError(message: error)
            }
        }
        .onAppear { Task { await viewModel.load() } }
        .confirmationDialog(
            "Leave this Project?",
            isPresented: $isConfirmingLeave,
            titleVisibility: .visible
        ) {
            Button("Leave", role: .destructive) {
                Task { _ = await viewModel.leave() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your posts stay. You'd need a new invitation to post again.")
        }
    }
}
