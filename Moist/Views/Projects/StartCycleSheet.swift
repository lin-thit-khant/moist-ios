//
//  StartCycleSheet.swift
//  Rawdea
//

import SwiftUI

/// Starts a shipped Project's next cycle, then asks who comes along.
struct StartCycleSheet: View {

    let project: Project
    let onStarted: (Project) async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StartCycleViewModel()

    private var nextNumber: Int { project.cycleNumber + 1 }

    var body: some View {

        NavigationStack {

            if let started = viewModel.started {

                ContributorsView(
                    projectId: started.id,
                    title: "Who comes along",
                    intro: "Cycle \(started.cycleNumber) starts with just you. Invite past helpers back whenever you like."
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }

            } else {

                form
            }
        }
        // The Project page updates once, behind the sheet.
        .onChange(of: viewModel.started?.id) { _, _ in
            guard let started = viewModel.started else { return }
            Task { await onStarted(started) }
        }
        .interactiveDismissDisabled(
            viewModel.isStarting ||
            (viewModel.started == nil && !viewModel.note.isEmpty)
        )
    }

    private var form: some View {

        Form {

            Section("Cycle name") {
                TextField("Optional", text: $viewModel.name, axis: .vertical)
                RawdeaCharacterLimitText(
                    count: RawdeaTextLength.count(viewModel.name),
                    limit: ProjectCycle.nameLimit,
                    threshold: 15
                )
            }

            Section("Start at") {
                Picker("Start at", selection: $viewModel.stage) {
                    ForEach(StartCycleViewModel.stages, id: \.self) { stage in
                        Text(stage.title).tag(stage)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                TextField(
                    "What is this cycle about?",
                    text: $viewModel.note,
                    axis: .vertical
                )
                .lineLimit(3...8)
                RawdeaCharacterLimitText(
                    count: RawdeaTextLength.count(viewModel.note),
                    limit: RawdeaPostDraft.characterLimit,
                    threshold: 40
                )
            } header: {
                Text("Opening note")
            } footer: {
                Text("It's published as your Note. You can undo the new cycle for a day, before anything else is posted or anyone joins.")
            }

            if let error = viewModel.errorMessage {
                RawdeaInlineError(message: error)
            }
        }
        .disabled(viewModel.isStarting)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .navigationTitle("Start Cycle \(nextNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(viewModel.isStarting)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isStarting {
                    ProgressView()
                } else {
                    Button("Start") {
                        Task { await viewModel.start(projectId: project.id) }
                    }
                    .disabled(!viewModel.canStart)
                }
            }
        }
        .onChange(of: viewModel.note) { _, _ in viewModel.clearError() }
        .onChange(of: viewModel.name) { _, _ in viewModel.clearError() }
    }
}
