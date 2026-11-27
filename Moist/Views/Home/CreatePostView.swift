//
//  CreatePostView.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//


import SwiftUI

struct CreatePostView: View {

    @StateObject private var viewModel =
        CreatePostViewModel()

    @Environment(\.dismiss)
    private var dismiss

    @State private var content = ""

    @State private var selectedProject: Project?
    @State private var kind = PostKind.note
    @State private var movesStage = false

    /// Project chosen before Compose opened, such as from a Project screen.
    private let initialProject: Project?

    @State private var isShowingProjectPicker = false
    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingStageFailure = false

    let onPostCreated: (Post) -> Void

    init(
        initialProject: Project? = nil,
        onPostCreated: @escaping (Post) -> Void
    ) {
        self.initialProject = initialProject
        self.onPostCreated = onPostCreated
        _selectedProject = State(initialValue: initialProject)
    }

    // MARK: - Draft state

    private var draft: RawdeaPostDraft {
        RawdeaPostDraft(content: content)
    }

    private var hasUnsavedDraft: Bool {

        !content.isEmpty ||
        selectedProject?.id != initialProject?.id
    }

    /// Only a progress post in a chosen, unshipped Project can move it on.
    private var nextStage: ProjectStage? {
        guard kind == .progress, let stage = selectedProject?.stage else {
            return nil
        }
        switch stage {
        case .early: return .inProgress
        case .inProgress: return .shipped
        case .shipped: return nil
        }
    }

    private var placeholder: String {
        switch kind {
        case .note: "What are you thinking about? Rough is fine."
        case .question: "What do you want to ask?"
        case .progress: "What changed since last time?"
        case .decision: "What did you decide, and why?"
        }
    }

    private var canPublish: Bool {

        draft.isValid &&
        !viewModel.isPublishing &&
        viewModel.publishedPost == nil
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.lg
                ) {

                    // The destination and the draft read as one block.
                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xs
                    ) {

                        projectChip

                        kindPicker

                        RawdeaPostEditor(
                            content: $content,
                            placeholder: placeholder,
                            isEnabled:
                                !viewModel.isPublishing,
                            isPlain: true
                        )
                    }

                    kindDetails

                    moderationNotice

                    if let error =
                        viewModel.errorMessage {

                        RawdeaInlineError(
                            message: error
                        )
                    }
                }
                .padding(
                    .horizontal,
                    RawdeaSpacing.screenInset
                )
                .padding(
                    .top,
                    RawdeaSpacing.xs
                )
                .padding(
                    .bottom,
                    RawdeaSpacing.lg
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                RawdeaPalette.canvas
                    .ignoresSafeArea()
            )

            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        requestDismissal()
                    }
                    .disabled(
                        viewModel.isPublishing
                    )
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }

                // Publish stays reachable while the
                // keyboard is up, matching Edit Profile.
                ToolbarItem(
                    placement: .confirmationAction
                ) {

                    Button("Publish") {
                        Task {
                            await publish()
                        }
                    }
                    .disabled(!canPublish)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isPublishing {
                    postingPill
                }
            }

            // Protect unsaved drafts from
            // accidental swipe dismissal.
            //
            // A deliberate Cancel action shows
            // the discard confirmation.
            .interactiveDismissDisabled(
                hasUnsavedDraft ||
                viewModel.isPublishing
            )

            .confirmationDialog(
                "Discard this post?",
                isPresented:
                    $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {

                Button(
                    "Discard Draft",
                    role: .destructive
                ) {

                    dismiss()
                }

                Button(
                    "Keep Editing",
                    role: .cancel
                ) { }

            } message: {

                Text(
                    "Your unpublished text and Project selection will be lost."
                )
            }

            // MARK: - Project picker

            .sheet(
                isPresented: $isShowingProjectPicker
            ) {

                ProjectPickerView(
                    selectedProject: $selectedProject
                )
            }
        }

        // Remove stale errors when the user
        // starts revising the post.
        .onChange(of: kind) { _, _ in

            movesStage = false
            viewModel.clearError()
        }
        .alert(
            "Posted, but the stage didn't change",
            isPresented: $isShowingStageFailure
        ) {
            Button("OK") { finishPublishing() }
        } message: {
            Text("Your post is published. You can move the stage from the Project's options.")
        }
        .onChange(of: content) { _, _ in

            viewModel.clearError()
        }

        .onChange(
            of: selectedProject?.id
        ) { _, _ in

            movesStage = false
            viewModel.clearError()
        }
    }

    // MARK: - Project destination

    private var projectChip: some View {

        Button {

            isShowingProjectPicker = true

        } label: {

            HStack(spacing: RawdeaSpacing.xxs) {

                Image(systemName: "folder")
                    .accessibilityHidden(true)

                Text(selectedProject.map { "\($0.name) · \($0.stage.title)" } ?? "General")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.down")
                    .font(RawdeaTypography.caption)
                    .accessibilityHidden(true)
            }
            .font(RawdeaTypography.metadata.weight(.semibold))
            // Red marks a chosen Project only.
            .foregroundStyle(
                selectedProject == nil
                ? RawdeaPalette.primaryText
                : RawdeaPalette.accent
            )
            .padding(.horizontal, RawdeaSpacing.sm)
            .padding(.vertical, RawdeaSpacing.xs)
            .background(
                RawdeaPalette.surface,
                in: RoundedRectangle(cornerRadius: RawdeaSpacing.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: RawdeaSpacing.lg)
                    .strokeBorder(RawdeaPalette.activityOutline)
            }
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPublishing)
        .accessibilityLabel(
            "Post destination, \(selectedProject?.name ?? "General")"
        )
        .accessibilityHint(
            "Choose a Project. Every post belongs to one."
        )
    }

    // MARK: - Kind

    private var kindPicker: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RawdeaSpacing.xs) {
                ForEach(PostKind.allCases, id: \.self) { item in
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
        .disabled(viewModel.isPublishing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Post type")
    }

    @ViewBuilder
    private var kindDetails: some View {

        if let nextStage, let current = selectedProject?.stage {

            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

                Toggle("Move to \(nextStage.title)", isOn: $movesStage)
                    .tint(RawdeaPalette.accent)
                    .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                    .disabled(viewModel.isPublishing)

                detailText(movesStage
                    ? "Followers will see the Project move to \(nextStage.title)."
                    : "The Project stays in \(current.title).")
            }

        } else if kind == .question {

            detailText("People can answer. You pick the best answer and the question closes as Answered.")
        }
    }

    private func detailText(_ text: String) -> some View {

        Text(text)
            .font(RawdeaTypography.metadata)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Publishing status

    // The sheet stays open until the server answers, so a
    // rejected post keeps its draft.
    private var postingPill: some View {

        HStack(spacing: RawdeaSpacing.xs) {

            ProgressView()
                .accessibilityHidden(true)

            Text("Posting…")
                .font(RawdeaTypography.authorName)
                .foregroundStyle(RawdeaPalette.primaryText)
        }
        .padding(.horizontal, RawdeaSpacing.md)
        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
        .background(RawdeaPalette.surface, in: Capsule())
        .overlay {
            Capsule().strokeBorder(RawdeaPalette.activityOutline)
        }
        .padding(.bottom, RawdeaSpacing.xs)
        .accessibilityElement(children: .combine)
        .onAppear {
            AccessibilityNotification.Announcement("Posting").post()
        }
    }

    // MARK: - Moderation disclosure

    private var moderationNotice: some View {

        HStack(
            alignment: .top,
            spacing: RawdeaSpacing.xs
        ) {

            Image(
                systemName: "checkmark.shield"
            )
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .accessibilityHidden(true)

            Text(
                "Posts are checked against Rawdea's content rules before publication."
            )
            .font(RawdeaTypography.metadata)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
    }

    // MARK: - Dismissal

    private func requestDismissal() {

        guard !viewModel.isPublishing else {
            return
        }

        if hasUnsavedDraft {

            isShowingDiscardConfirmation = true

        } else {

            dismiss()
        }
    }

    // MARK: - Publication

    @MainActor
    private func publish() async {

        guard canPublish else {
            return
        }

        let success = await viewModel.publish(
            content: draft.trimmedContent,
            projectId: selectedProject?.id,
            kind: kind,
            newStage: movesStage ? nextStage : nil
        )

        guard success else {
            // Keep the draft and Project
            // selection on publication failure.
            return
        }

        if viewModel.stageChangeFailed {
            isShowingStageFailure = true
        } else {
            finishPublishing()
        }
    }

    private func finishPublishing() {

        guard let publishedPost = viewModel.publishedPost else {
            return
        }

        // Preserve Batch 2's successful
        // publication routing contract.
        onPostCreated(publishedPost)

        dismiss()
    }
}
