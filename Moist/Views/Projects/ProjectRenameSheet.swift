//
//  ProjectRenameSheet.swift
//  Rawdea
//

import SwiftUI

/// Rename form shared by the Profile Project list and the Project screen.
struct ProjectRenameSheet: View {

    @ObservedObject var viewModel: ProjectsViewModel
    let project: Project
    let onRenamed: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(
        viewModel: ProjectsViewModel,
        project: Project,
        onRenamed: @escaping () async -> Void = {}
    ) {
        self.viewModel = viewModel
        self.project = project
        self.onRenamed = onRenamed
        _name = State(initialValue: project.name)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty &&
        RawdeaTextLength.count(trimmedName) <= 80 &&
        trimmedName != project.name &&
        !viewModel.isUpdating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityLabel("Project name")
                } header: {
                    Text("Project name")
                } footer: {
                    Text("Up to 80 characters.")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        RawdeaInlineError(message: error)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RawdeaPalette.canvas)
            .navigationTitle("Rename Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.clearError()
                        dismiss()
                    }
                    .disabled(viewModel.isUpdating)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isUpdating {
                        ProgressView()
                            .accessibilityLabel("Saving name")
                    } else {
                        Button("Save") {
                            Task {
                                let success = await viewModel.renameProject(
                                    projectId: project.id,
                                    name: trimmedName
                                )

                                if success {
                                    await onRenamed()
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(viewModel.isUpdating)
        }
        .onAppear { viewModel.clearError() }
    }
}
