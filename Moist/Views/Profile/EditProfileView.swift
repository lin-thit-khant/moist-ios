//
//  EditProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 2/11/2569 BE.
//


import SwiftUI

struct EditProfileView: View {

    @ObservedObject var viewModel:
        ProfileViewModel

    let profile: Profile

    @Environment(\.dismiss)
    private var dismiss

    @State private var displayName: String
    @State private var bio: String

    @State private var showDiscardConfirmation = false

    init(
        viewModel: ProfileViewModel,
        profile: Profile
    ) {
        self.viewModel = viewModel
        self.profile = profile

        _displayName = State(
            initialValue: profile.displayname
        )

        _bio = State(
            initialValue: profile.bio
        )
    }

    // MARK: - Validation

    private var trimmedName: String {
        displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var displayNameCharacterCount: Int {

        RawdeaTextLength.count(displayName)
    }

    private var bioCharacterCount: Int {

        RawdeaTextLength.count(bio)
    }

    private var isValid: Bool {

        displayNameCharacterCount <= 80 &&
        bioCharacterCount <= 160
    }

    private var hasUnsavedChanges: Bool {

        displayName != profile.displayname ||
        bio != profile.bio
    }

    private var hasSubmittableChanges: Bool {

        trimmedName != profile.displayname
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ||
        bio.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) != profile.bio.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSave: Bool {

        isValid &&
        hasSubmittableChanges &&
        !viewModel.isSaving
    }

    var body: some View {

        Form {

            Section {

                TextField(
                    "Your display name",
                    text: $displayName
                )
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(RawdeaTypography.body)
                .accessibilityLabel("Display name")
                .disabled(viewModel.isSaving)
                
                characterStatus(
                    count: displayNameCharacterCount,
                    limit: 80
                )

            } header: {

                Text("Display name")

            } footer: {

                Text(
                    "This is the name people see on your posts and profile. Up to 80 characters."
                )
            }

            Section {

                // Grows with its content instead of reserving a fixed block.
                TextField(
                    "A little about you",
                    text: $bio,
                    axis: .vertical
                )
                    .font(RawdeaTypography.body)
                    .lineLimit(3...8)
                    .accessibilityLabel("Bio")
                    .disabled(viewModel.isSaving)
                
                characterStatus(
                    count: bioCharacterCount,
                    limit: 160
                )

            } header: {

                Text("Bio")

            } footer: {

                Text(
                    "Share a little about yourself and what you enjoy creating. Up to 160 characters."
                )
            }

            if let error = viewModel.errorMessage {

                Section {

                    RawdeaInlineError(
                        message: error
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .scrollDismissesKeyboard(.interactively)

        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)

        // Hide the default Back control so
        // Cancel can protect unsaved changes.
        .navigationBarBackButtonHidden(true)

        .toolbar {

            ToolbarItem(
                placement: .topBarLeading
            ) {

                Button("Cancel") {

                    requestDismissal()
                }
                .disabled(viewModel.isSaving)
            }

            ToolbarItem(
                placement: .confirmationAction
            ) {

                if viewModel.isSaving {

                    ProgressView()
                        .accessibilityLabel("Saving profile")

                } else {

                    Button("Save") {

                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }

        .confirmationDialog(
            "Discard profile changes?",
            isPresented:
                $showDiscardConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Discard Changes",
                role: .destructive
            ) {

                viewModel.clearMessages()
                dismiss()
            }

            Button(
                "Keep Editing",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Your unsaved profile changes will be lost."
            )
        }

        .onAppear {

            viewModel.clearMessages()
        }

        .onChange(of: displayName) { _, _ in

            viewModel.clearMessages()
        }

        .onChange(of: bio) { _, _ in

            viewModel.clearMessages()
        }
    }

    // MARK: - Character counts

    /// Stays quiet until the text is close to the limit, then shows
    /// what is left, and turns into an error once the limit is passed.
    @ViewBuilder
    private func characterStatus(
        count: Int,
        limit: Int
    ) -> some View {

        let remaining = limit - count

        if remaining < 0 {

            Label(
                "\(-remaining) over the \(limit)-character limit",
                systemImage: "exclamationmark.circle"
            )
            .font(RawdeaTypography.caption)
            .foregroundStyle(RawdeaPalette.danger)

        } else if remaining <= 20 {

            Text(
                remaining == 1
                ? "1 character left"
                : "\(remaining) characters left"
            )
            .font(RawdeaTypography.caption)
            .foregroundStyle(RawdeaPalette.secondaryText)
        }
    }

    // MARK: - Cancel

    private func requestDismissal() {

        guard !viewModel.isSaving else {
            return
        }

        if hasUnsavedChanges {

            showDiscardConfirmation = true

        } else {

            viewModel.clearMessages()
            dismiss()
        }
    }

    // MARK: - Save

    @MainActor
    private func saveProfile() async {

        guard canSave else {
            return
        }

        await viewModel.updateProfile(
            displayName: trimmedName,
            bio: bio
        )

        // ProfileViewModel reports success
        // through its existing status message.
        guard viewModel.errorMessage == nil,
              viewModel.statusMessage != nil else {
            return
        }

        dismiss()
    }
}
