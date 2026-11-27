//
//  CreatePostView.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//


import Supabase
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
    @State private var authorName: String?

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

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

                composerBody
                    .padding(.horizontal, RawdeaSpacing.screenInset)
                    .padding(.vertical, RawdeaSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                RawdeaPalette.canvas
                    .ignoresSafeArea()
            )

            .navigationTitle("New post")
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

            }
            // Post stays above the keyboard.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                postBar
            }
            .task {
                await loadAuthorName()
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

    // MARK: - Layout

    /// An avatar with its thread line beside who, where and what.
    private var composerBody: some View {

        HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

            if !dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: RawdeaSpacing.xs) {
                    RawdeaInitialAvatar(name: authorName ?? "?")
                    Capsule()
                        .fill(RawdeaPalette.divider)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                if let authorName {
                    Text(authorName)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                }

                projectChip

                kindPicker

                RawdeaPostEditor(
                    content: $content,
                    placeholder: placeholder,
                    isEnabled: !viewModel.isPublishing,
                    isPlain: true
                )

                kindDetails

                if let error = viewModel.errorMessage {
                    RawdeaInlineError(message: error)
                }
            }
        }
    }

    private var postBar: some View {

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: RawdeaSpacing.xs))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.sm))

        return layout {

            Text("Every idea goes in a Project")
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Task { await publish() }
            } label: {
                HStack(spacing: RawdeaSpacing.xs) {
                    if viewModel.isPublishing {
                        ProgressView()
                            .tint(RawdeaPalette.onAccent)
                    }
                    Text(viewModel.isPublishing ? "Posting…" : "Post")
                }
                .font(RawdeaTypography.authorName)
                .foregroundStyle(canPublish || viewModel.isPublishing
                    ? RawdeaPalette.onAccent
                    : RawdeaPalette.secondaryText)
                .padding(.horizontal, RawdeaSpacing.lg)
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                .background(
                    canPublish || viewModel.isPublishing
                        ? RawdeaPalette.accent
                        : RawdeaPalette.surface,
                    in: RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canPublish)
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.vertical, RawdeaSpacing.xs)
        .background(RawdeaPalette.canvas)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .onChange(of: viewModel.isPublishing) { _, isPublishing in
            if isPublishing {
                AccessibilityNotification.Announcement("Posting").post()
            }
        }
    }

    private func loadAuthorName() async {
        guard let user = try? await SupabaseManager.client.auth.session.user else {
            return
        }
        authorName = try? await ProfileService()
            .fetchProfile(userId: user.id)
            .username
    }

    // MARK: - Project destination

    private var projectChip: some View {

        Button {

            isShowingProjectPicker = true

        } label: {

            HStack(spacing: RawdeaSpacing.xxs) {

                RawdeaInitialAvatar(
                    name: selectedProject?.name ?? "General",
                    size: RawdeaSpacing.lg,
                    font: RawdeaTypography.caption.weight(.bold)
                )

                Text(selectedProject.map { "\($0.name) · \($0.stage.title)" } ?? "General")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Image(systemName: "chevron.down")
                    .font(RawdeaTypography.caption)
                    .accessibilityHidden(true)
            }
            .font(RawdeaTypography.metadata.weight(.semibold))
            .foregroundStyle(RawdeaPalette.primaryText)
            .padding(.horizontal, RawdeaSpacing.sm)
            .padding(.vertical, RawdeaSpacing.xs)
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

            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                Text("Project stage")
                    .font(RawdeaTypography.secondary.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)

                stageChoice(current: current, next: nextStage)

                detailText(movesStage
                    ? "Followers will see \"\(selectedProject?.name ?? "Project") moved to \(nextStage.title)\" on Home."
                    : "The stage stays the same.")
            }

        } else if kind == .question {

            detailText("People can answer. You pick the best answer and the question closes as Answered.")
        }
    }

    private func stageChoice(
        current: ProjectStage,
        next: ProjectStage
    ) -> some View {

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))

        return layout {
            stageSegment("Stay in \(current.title)", moves: false)
            stageSegment("Move to \(next.title)", moves: true)
        }
        .clipShape(RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius))
        .overlay {
            RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                .strokeBorder(RawdeaPalette.activityOutline)
                .allowsHitTesting(false)
        }
        .disabled(viewModel.isPublishing)
    }

    private func stageSegment(_ title: String, moves: Bool) -> some View {

        let isSelected = movesStage == moves

        return Button {
            movesStage = moves
        } label: {
            Text(title)
                .font(RawdeaTypography.secondary.weight(.semibold))
                .foregroundStyle(isSelected
                    ? RawdeaPalette.primaryText
                    : RawdeaPalette.secondaryText)
                .multilineTextAlignment(.center)
                .padding(RawdeaSpacing.xs)
                .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
                .background(isSelected ? RawdeaPalette.surface : RawdeaPalette.canvas)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func detailText(_ text: String) -> some View {

        Text(text)
            .font(RawdeaTypography.metadata)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
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
