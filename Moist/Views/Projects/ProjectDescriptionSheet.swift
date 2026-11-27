//
//  ProjectDescriptionSheet.swift
//  Rawdea
//

import SwiftUI

/// Edits a Project's short public description.
struct ProjectDescriptionSheet: View {

    private static let limit = 280

    let project: Project
    let onSaved: (Project) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        project: Project,
        onSaved: @escaping (Project) async -> Void
    ) {
        self.project = project
        self.onSaved = onSaved
        _text = State(initialValue: project.about)
    }

    var body: some View {

        NavigationStack {

            Form {

                Section {
                    TextField(
                        "What are you making?",
                        text: $text,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .disabled(isSaving)
                } footer: {
                    RawdeaCharacterLimitText(
                        count: RawdeaTextLength.count(text),
                        limit: Self.limit,
                        threshold: 40
                    )
                }

                if let errorMessage {
                    RawdeaInlineError(message: errorMessage)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RawdeaPalette.canvas)
            .navigationTitle("Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                        .disabled(RawdeaTextLength.count(text) > Self.limit)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // The sheet stays open until the server accepts the text.
    private func save() async {

        isSaving = true
        errorMessage = nil

        defer { isSaving = false }

        do {
            let updated = try await ProjectService()
                .setDescription(projectId: project.id, description: text)
            await onSaved(updated)
            dismiss()
        } catch {
            errorMessage = PublicationErrorMessage.from(error)
        }
    }
}
