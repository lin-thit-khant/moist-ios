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

    /// Project chosen before Compose opened, such as from a Project screen.
    private let initialProject: Project?

    @State private var isShowingProjectPicker = false
    @State private var isShowingDiscardConfirmation = false

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

    private var canPublish: Bool {

        draft.isValid &&
        !viewModel.isPublishing
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

                        RawdeaPostEditor(
                            content: $content,
                            placeholder:
                                "Share something worth remembering.",
                            isEnabled:
                                !viewModel.isPublishing,
                            isPlain: true
                        )
                    }

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
        .onChange(of: content) { _, _ in

            viewModel.clearError()
        }

        .onChange(
            of: selectedProject?.id
        ) { _, _ in

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

                Text(selectedProject?.name ?? "Add to Project")
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
            "Post destination, \(selectedProject?.name ?? "No Project")"
        )
        .accessibilityHint(
            "Choose a Project, or publish to your profile"
        )
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
            projectId: selectedProject?.id
        )

        guard success,
              let publishedPost =
                  viewModel.publishedPost else {
            // Keep the draft and Project
            // selection on publication failure.
            return
        }

        // Preserve Batch 2's successful
        // publication routing contract.
        onPostCreated(publishedPost)

        dismiss()
    }
}
