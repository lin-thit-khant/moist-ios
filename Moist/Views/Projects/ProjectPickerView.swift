//
//  ProjectPickerView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 9/11/2569 BE.
//


import SwiftUI
import Supabase

struct ProjectPickerView: View {

    @Binding var selectedProject: Project?

    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var viewModel =
        ProjectsViewModel()

    @State private var newProjectName = ""
    @State private var isShowingCreateAlert = false
    @State private var sessionError: String?

    // MARK: - Body

    var body: some View {

        NavigationStack {

            Form {

                Section {

                    noProjectOption

                    ForEach(viewModel.projects.filter { !$0.isDefault }) { project in

                        projectOption(project)
                    }

                    if viewModel.isLoading {

                        RawdeaLoadingIndicator(
                            "Loading Projects..."
                        )
                    }

                    if viewModel.projects.isEmpty &&
                       !viewModel.isLoading &&
                       viewModel.errorMessage == nil {

                        Text("No Projects yet.")
                            .font(
                                RawdeaTypography.secondary
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                    }

                } header: {

                    Text("Post destination")

                } footer: {

                    Text(
                        "Every post belongs to a Project. General holds everything else."
                    )
                }

                Section {

                    Button {

                        newProjectName = ""
                        viewModel.clearError()

                        isShowingCreateAlert = true

                    } label: {

                        Label(
                            "Create New Project",
                            systemImage: "plus"
                        )
                        .font(
                            RawdeaTypography.authorName
                        )
                        .frame(
                            minHeight:
                                RawdeaSpacing.minimumTouchTarget
                        )
                    }
                    .disabled(
                        viewModel.isCreating
                    )
                }

                if let error =
                    viewModel.errorMessage
                    ?? sessionError {

                    Section {

                        RawdeaInlineError(
                            message: error
                        )
                    }
                }

                if viewModel.isCreating {

                    Section {

                        ProgressView(
                            "Creating Project..."
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                RawdeaPalette.canvas
                    .ignoresSafeArea()
            )

            .navigationTitle("Choose Project")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(
                        viewModel.isCreating
                    )
                }
            }

            .interactiveDismissDisabled(
                viewModel.isCreating
            )

            // MARK: - Create Project

            .alert(
                "New Project",
                isPresented:
                    $isShowingCreateAlert
            ) {

                TextField(
                    "Project name",
                    text: $newProjectName
                )

                Button(
                    "Cancel",
                    role: .cancel
                ) { }

                Button("Create") {

                    Task {

                        await createProject()
                    }
                }

            } message: {

                Text(
                    "Give your Project a name of up to 80 characters."
                )
            }

            // MARK: - Initial load

            .task {

                do {

                    let user = try await SupabaseManager
                        .client
                        .auth
                        .session
                        .user

                    await viewModel.loadProjects(
                        userId: user.id
                    )

                } catch {

                    sessionError =
                        "Please sign in again."
                }
            }
        }
    }

    // MARK: - Free post

    private var noProjectOption: some View {

        Button {

            selectedProject = nil
            dismiss()

        } label: {

            HStack(spacing: RawdeaSpacing.sm) {

                Image(
                    systemName: "text.alignleft"
                )
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityHidden(true)

                Text("General")
                    .font(RawdeaTypography.body)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )

                Spacer(minLength: 0)

                if selectedProject == nil {

                    Image(
                        systemName: "checkmark"
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .accessibilityHidden(true)
                }
            }
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "General"
        )
        .accessibilityAddTraits(
            selectedProject == nil
            ? .isSelected
            : []
        )
    }

    // MARK: - Project option

    private func projectOption(
        _ project: Project
    ) -> some View {

        Button {

            selectedProject = project
            dismiss()

        } label: {

            HStack(
                spacing: RawdeaSpacing.sm
            ) {

                Image(systemName: "folder")
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .accessibilityHidden(true)

                Text(project.name)
                    .font(RawdeaTypography.body)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                Spacer(minLength: 0)

                if selectedProject?.id == project.id {

                    Image(
                        systemName: "checkmark"
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .accessibilityHidden(true)
                }
            }
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            project.name
        )
        .accessibilityAddTraits(
            selectedProject?.id == project.id
            ? .isSelected
            : []
        )
    }

    // MARK: - Create Project

    @MainActor
    private func createProject() async {

        let created = await viewModel.creatProject(
            name: newProjectName
        )

        guard created,
              let project =
                  viewModel.projects.first else {
            return
        }

        // ProjectsViewModel inserts a newly
        // created Project at index zero.
        selectedProject = project

        dismiss()
    }
}
