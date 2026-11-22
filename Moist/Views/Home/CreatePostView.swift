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

    @State private var isShowingProjectPicker = false
    @State private var isShowingDiscardConfirmation = false

    let onPostCreated: (Post) -> Void

    // MARK: - Draft state

    private var draft: RawdeaPostDraft {
        RawdeaPostDraft(content: content)
    }

    private var hasUnsavedDraft: Bool {

        !content.isEmpty ||
        selectedProject != nil
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

                    introduction

                    RawdeaPostEditor(
                        content: $content,
                        placeholder:
                            "Share something worth remembering.",
                        isEnabled:
                            !viewModel.isPublishing
                    )

                    projectDestination

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

            // MARK: - Primary action

            .safeAreaInset(
                edge: .bottom,
                spacing: 0
            ) {

                publishFooter
            }

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

    // MARK: - Introduction

    private var introduction: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text("A new thought")
                .font(
                    RawdeaTypography.screenTitle
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )

            Text(
                "Write freely, then choose where it belongs."
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

    // MARK: - Project destination

    private var projectDestination: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text("POST DESTINATION")
                .font(RawdeaTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityAddTraits(.isHeader)

            Button {

                isShowingProjectPicker = true

            } label: {

                HStack(
                    spacing: RawdeaSpacing.sm
                ) {

                    Image(systemName: "folder")
                        .font(.system(.body))
                        .foregroundStyle(
                            RawdeaPalette.accent
                        )
                        .accessibilityHidden(true)

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xxs
                    ) {

                        Text(
                            selectedProject?.name
                            ?? "No Project"
                        )
                        .font(
                            RawdeaTypography.authorName
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )

                        Text(
                            selectedProject == nil
                            ? "Publish to your free posts"
                            : "Publish inside this Project"
                        )
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )

                    Image(systemName: "chevron.right")
                        .font(.system(.subheadline))
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .accessibilityHidden(true)
                }
                .padding(RawdeaSpacing.md)
                .frame(
                    maxWidth: .infinity,
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget,
                    alignment: .leading
                )
                .background(
                    RawdeaPalette.surface,
                    in: RoundedRectangle(
                        cornerRadius:
                            RawdeaSpacing.buttonRadius
                    )
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPublishing)
            .accessibilityLabel(
                "Post destination, \(selectedProject?.name ?? "No Project")"
            )
            .accessibilityHint(
                "Choose a Project or free post"
            )
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

    // MARK: - Publish footer

    private var publishFooter: some View {

        VStack(spacing: 0) {

            Divider()
                .overlay(RawdeaPalette.divider)

            RawdeaPrimaryButton(
                "Publish Post",
                isLoading:
                    viewModel.isPublishing,
                isEnabled:
                    canPublish
            ) {

                Task {

                    await publish()
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
