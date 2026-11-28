//
//  SuggestUpdateSheet.swift
//  Rawdea
//

import SwiftUI

/// A follower offers one update to someone else's Project.
struct SuggestUpdateSheet: View {

    let project: Project
    let onSent: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SuggestUpdateViewModel()

    @State private var kind = PostKind.note
    @State private var content = ""

    private var canSend: Bool {
        RawdeaPostDraft(content: content).isValid && !viewModel.isSending
    }

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {

                    Text(project.name)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: RawdeaSpacing.xs) {
                            ForEach(ProjectSuggestion.kinds, id: \.self) { item in
                                RawdeaChip(
                                    title: item.title,
                                    symbol: item.symbol,
                                    isSelected: kind == item
                                ) {
                                    kind = item
                                }
                            }
                        }
                    }
                    .disabled(viewModel.isSending)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Suggestion type")

                    RawdeaPostEditor(
                        content: $content,
                        placeholder: "What would you add?",
                        isEnabled: !viewModel.isSending,
                        isPlain: true
                    )

                    RawdeaNoteDetail("The owner reads it first. If approved, it appears in the Project under your name, marked Suggested.")

                    if let error = viewModel.errorMessage {
                        RawdeaInlineError(message: error)
                    }
                }
                .padding(.horizontal, RawdeaSpacing.screenInset)
                .padding(.vertical, RawdeaSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(RawdeaPalette.canvas.ignoresSafeArea())
            .navigationTitle("Suggest an update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isSending)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                RawdeaPillButton(
                    title: viewModel.isSending ? "Sending…" : "Send suggestion",
                    isPrimary: true,
                    isWorking: viewModel.isSending
                ) {
                    Task { await send() }
                }
                .disabled(!canSend)
                .opacity(canSend || viewModel.isSending ? 1 : 0.5)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, RawdeaSpacing.screenInset)
                .padding(.vertical, RawdeaSpacing.xs)
                .background(RawdeaPalette.canvas)
            }
            .interactiveDismissDisabled(!content.isEmpty || viewModel.isSending)
            .onChange(of: content) { _, _ in viewModel.clearError() }
            .onChange(of: kind) { _, _ in viewModel.clearError() }
        }
    }

    private func send() async {
        if await viewModel.send(projectId: project.id, kind: kind, content: content) {
            AccessibilityNotification.Announcement("Suggestion sent").post()
            await onSent()
            dismiss()
        }
    }
}
