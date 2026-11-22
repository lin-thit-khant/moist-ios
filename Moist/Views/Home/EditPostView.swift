//
//  EditPostView.swift
//  Moist
//
//  Created by Lin Thit Khant on 4/11/2569 BE.
//

import SwiftUI

struct EditPostView: View {

    let post: Post

    @ObservedObject var viewModel: FeedViewModel

    @Environment(\.dismiss)
    private var dismiss

    @State private var content: String

    @State private var isShowingDiscardConfirmation = false

    init(
        post: Post,
        viewModel: FeedViewModel
    ) {

        self.post = post
        self.viewModel = viewModel

        _content = State(
            initialValue: post.content
        )
    }

    // MARK: - State

    private var draft: RawdeaPostDraft {
        RawdeaPostDraft(content: content)
    }

    private var isSaving: Bool {
        viewModel.editingPostId == post.id
    }

    private var hasUnsavedChanges: Bool {

        draft.hasUnsavedChanges(
            comparedTo: post.content
        )
    }

    private var canSave: Bool {

        draft.hasSubmittableChanges(
            comparedTo: post.content
        ) &&
        !isSaving
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.lg
                ) {

                    introduction

                    RawdeaPostEditor(
                        content: $content,
                        placeholder:
                            "Edit your thought...",
                        isEnabled: !isSaving
                    )

                    originalPostInformation

                    if draft.isEmpty &&
                       !content.isEmpty {

                        RawdeaInlineError(
                            message:
                                "Post content cannot be empty."
                        )
                    }

                    if let error =
                        viewModel.editErrorMessage {

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
                    RawdeaSpacing.md
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

            .safeAreaInset(
                edge: .bottom,
                spacing: 0
            ) {

                saveFooter
            }

            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Cancel") {
                        requestDismissal()
                    }
                    .disabled(isSaving)
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
            }

            .interactiveDismissDisabled(
                hasUnsavedChanges || isSaving
            )

            .confirmationDialog(
                "Discard your changes?",
                isPresented:
                    $isShowingDiscardConfirmation,
                titleVisibility: .visible
            ) {

                Button(
                    "Discard Changes",
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
                    "Your changes to this post will not be saved."
                )
            }
        }

        .onAppear {

            viewModel.clearEditError()
        }

        .onChange(of: content) { _, _ in

            viewModel.clearEditError()
        }
    }

    // MARK: - Introduction

    private var introduction: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text("Refine your thought")
                .font(
                    RawdeaTypography.screenTitle
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )

            Text(
                "Make your changes and save when you're ready."
            )
            .font(RawdeaTypography.secondary)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    // MARK: - Original metadata

    private var originalPostInformation: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            Text("POST DETAILS")
                .font(RawdeaTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityAddTraits(.isHeader)

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.sm
            ) {

                Image(systemName: "clock")
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xxs
                ) {

                    Text("Originally published")
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )

                    
                    Text(
                        post.createdAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(RawdeaTypography.caption)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

                }
            }

            if let project = post.project {

                HStack(
                    alignment: .top,
                    spacing: RawdeaSpacing.sm
                ) {

                    Image(systemName: "folder")
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .accessibilityHidden(true)

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xxs
                    ) {

                        Text("Project")
                            .font(
                                RawdeaTypography.metadata
                            )
                            .foregroundStyle(
                                RawdeaPalette.primaryText
                            )

                        Text(project.name)
                            .font(
                                RawdeaTypography.secondary
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                    }
                }

            } else {

                Label(
                    "Free post",
                    systemImage: "text.alignleft"
                )
                .font(RawdeaTypography.metadata)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
            }

            Text(
                "To change the Project or visibility, use the existing post options."
            )
            .font(RawdeaTypography.caption)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(RawdeaSpacing.md)
        .background(
            RawdeaPalette.surface,
            in: RoundedRectangle(
                cornerRadius:
                    RawdeaSpacing.cardRadius
            )
        )
    }

    // MARK: - Save footer

    private var saveFooter: some View {

        VStack(spacing: 0) {

            Divider()
                .overlay(RawdeaPalette.divider)

            RawdeaPrimaryButton(
                "Save Changes",
                isLoading: isSaving,
                isEnabled: canSave
            ) {

                Task {

                    await saveChanges()
                }
            }
            .padding(
                .horizontal,
                RawdeaSpacing.screenInset
            )
            .padding(
                .vertical,
                RawdeaSpacing.sm
            )
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea(
                    edges: .bottom
                )
        )
    }

    // MARK: - Dismissal

    private func requestDismissal() {

        guard !isSaving else {
            return
        }

        if hasUnsavedChanges {

            isShowingDiscardConfirmation = true

        } else {

            dismiss()
        }
    }

    // MARK: - Save changes

    @MainActor
    private func saveChanges() async {

        guard canSave else {
            return
        }

        let didSave = await viewModel.updatePost(
            postId: post.id,
            content: draft.trimmedContent
        )

        guard didSave else {
            // Preserve the user's edited text.
            return
        }

        dismiss()
    }
}
