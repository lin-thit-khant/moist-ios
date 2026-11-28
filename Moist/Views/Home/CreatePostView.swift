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
    @State private var creditedNames: [String] = []

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    /// Project chosen before Compose opened, such as from a Project screen.
    private let initialProject: Project?
    private let userId: UUID
    @State private var restoredDraft: SavedPostDraft?

    @State private var needsProjectCheck: Bool
    @State private var projectCheckMessage: String?

    @State private var isShowingProjectPicker = false
    @State private var isShowingDiscardConfirmation = false
    @State private var isShowingStageFailure = false
    @State private var heldMovedStage = false

    let onPostCreated: (Post) -> Void

    init(
        userId: UUID,
        initialProject: Project? = nil,
        onPostCreated: @escaping (Post) -> Void
    ) {
        // An archived Project takes no new posts.
        let usable = initialProject?.isArchived == true ? nil : initialProject
        let saved = SavedPostDraft.load(for: userId)
        self.userId = userId
        _restoredDraft = State(initialValue: saved)
        self.initialProject = usable
        _content = State(initialValue: saved?.content ?? "")
        _kind = State(initialValue: saved?.kind ?? .note)
        _needsProjectCheck = State(initialValue: saved != nil)
        self.onPostCreated = onPostCreated
        _selectedProject = State(initialValue: saved == nil ? usable : nil)
    }

    // MARK: - Draft state

    private var draft: RawdeaPostDraft {
        RawdeaPostDraft(content: content)
    }

    private var hasUnsavedDraft: Bool {

        restoredDraft != nil || !content.isEmpty || kind != .note ||
        selectedProject?.id != initialProject?.id
    }

    private var draftToSave: SavedPostDraft? {
        guard hasUnsavedDraft else { return nil }
        return SavedPostDraft(
            content: content,
            projectId: needsProjectCheck ? restoredDraft?.projectId : selectedProject?.id,
            kind: kind
        )
    }

    private func restoreProject() async {
        guard needsProjectCheck, let restoredDraft else { return }

        do {
            var projects = try await ProjectService().fetchProjects(userId: userId)
            if let id = restoredDraft.projectId,
               !projects.contains(where: { $0.id == id }) {
                projects += try await CollaborationService()
                    .fetchContributingProjects()
            }
            guard !Task.isCancelled, needsProjectCheck else { return }
            let project = projects.first { project in
                restoredDraft.projectId.map { $0 == project.id } ?? project.isDefault
            }
            let unavailable = project?.isArchived == true ||
                (restoredDraft.projectId != nil && project == nil)
            if unavailable {
                projectCheckMessage = "The saved Project is unavailable. Choose a Project to continue."
                return
            }

            selectedProject = restoredDraft.projectId == nil ? nil : project
            needsProjectCheck = false
        } catch {
            guard !Task.isCancelled, needsProjectCheck else { return }
            projectCheckMessage = "Couldn't check the saved Project. Choose a Project to continue."
        }
    }

    /// Posting in someone else's Project as a contributor.
    private var isContribution: Bool {
        selectedProject.map { $0.userId != userId } ?? false
    }

    private var kinds: [PostKind] {
        isContribution
            ? PostKind.allCases.filter { $0 != .decision }
            : PostKind.allCases
    }

    /// Only a progress post in a chosen, unshipped Project can move it on.
    private var nextStage: ProjectStage? {
        guard !isContribution, kind == .progress,
              let stage = selectedProject?.stage else {
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
        !needsProjectCheck &&
        !viewModel.isPublishing &&
        viewModel.publishedPost == nil &&
        viewModel.heldReason == nil
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                Group {
                    if let reason = viewModel.heldReason {
                        heldNote(reason)
                    } else {
                        composerBody
                    }
                }
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

                    if viewModel.heldReason == nil {
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

            }
            // Post stays above the keyboard.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.heldReason == nil {
                    postBar
                }
            }
            .task {
                await restoreProject()
            }
            .task {
                await loadAuthorName()
            }
            .task(id: movesStage ? nextStage : nil) {
                creditedNames = []
                guard movesStage, let nextStage,
                      let projectId = selectedProject?.id else { return }
                creditedNames = (try? await CollaborationService()
                    .creditPreview(projectId: projectId, stage: nextStage)) ?? []
            }

            // Protect unsaved drafts from
            // accidental swipe dismissal.
            //
            // A deliberate Cancel action shows
            // the discard confirmation.
            .interactiveDismissDisabled(
                (hasUnsavedDraft && viewModel.heldReason == nil) ||
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

                    SavedPostDraft.save(nil, for: userId)
                    dismiss()
                }

                Button("Save Draft") {
                    SavedPostDraft.save(draftToSave, for: userId)
                    dismiss()
                }

                Button(
                    "Keep Editing",
                    role: .cancel
                ) { }

            } message: {

                Text(
                    "You can save this draft on this device or discard it."
                )
            }

            // MARK: - Project picker

            .sheet(
                isPresented: $isShowingProjectPicker
            ) {

                ProjectPickerView(
                    selectedProject: Binding(
                        get: { selectedProject },
                        set: { project in
                            selectedProject = project
                            needsProjectCheck = false
                            projectCheckMessage = nil
                        }
                    )
                )
            }
        }

        .onChange(of: draftToSave) { _, updated in
            guard viewModel.publishedPost == nil,
                  viewModel.heldReason == nil else { return }
            SavedPostDraft.save(updated, for: userId)
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
            // Decisions belong to the owner.
            if isContribution && kind == .decision {
                kind = .note
            }
            viewModel.clearError()
        }
    }

    // MARK: - Held for review

    private func heldNote(_ reason: HoldReason) -> some View {

        VStack(alignment: .leading, spacing: RawdeaSpacing.md) {

            RawdeaNote(
                title: "Sent for a quick check",
                message: "A moderator will look at this before it shows up. You can leave the app. We will tell you the result in Activity."
            ) {
                RawdeaNoteDetail("Reason: \(reason.text)")
                if heldMovedStage {
                    RawdeaNoteDetail("The Project stage didn't change.")
                }
            }

            RawdeaPillButton(title: "Done", isPrimary: true) {
                dismiss()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
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

                if let projectCheckMessage {
                    RawdeaInlineError(message: projectCheckMessage)
                } else if needsProjectCheck {
                    ProgressView("Checking draft Project…")
                }

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
                ForEach(kinds, id: \.self) { item in
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

        if isContribution {

            detailText("Need a decision? Post a Question and the owner decides.")
        }

        if let nextStage, let current = selectedProject?.stage {

            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                Text("Project stage")
                    .font(RawdeaTypography.secondary.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)

                stageChoice(current: current, next: nextStage)

                detailText(movesStage
                    ? "Followers will see \"\(selectedProject?.name ?? "Project") moved to \(nextStage.title)\" on Home."
                    : "The stage stays the same.")

                if movesStage, !creditedNames.isEmpty {
                    detailText("\(CreditNames.sentence(creditedNames)) will be named.")
                }
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
        // Both halves take the height of the taller title.
        .fixedSize(horizontal: false, vertical: true)
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
                .fixedSize(horizontal: false, vertical: true)
                .padding(RawdeaSpacing.xs)
                .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget, maxHeight: .infinity)
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
            newStage: movesStage ? nextStage : nil,
            isContribution: isContribution
        )

        guard success else {
            // Keep the draft and Project
            // selection on publication failure.
            return
        }

        SavedPostDraft.save(nil, for: userId)

        if viewModel.heldReason != nil {
            // The composer now shows the notice.
            AccessibilityNotification.Announcement("Sent for a quick check").post()
            heldMovedStage = movesStage && nextStage != nil
        } else if viewModel.stageChangeFailed {
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
