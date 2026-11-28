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
    @State private var username: String
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

        _username = State(
            initialValue: profile.username
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
        Profile.isValidUsername(username) &&
        bioCharacterCount <= 160
    }

    private var hasUnsavedChanges: Bool {

        displayName != profile.displayname ||
        username != profile.username ||
        bio != profile.bio
    }

    private var hasSubmittableChanges: Bool {

        trimmedName != profile.displayname
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ||
        username != profile.username ||
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

                // Wraps instead of truncating at large
                // text sizes. Return adds nothing, and
                // pasted line breaks become spaces.
                TextField(
                    "Your display name",
                    text: $displayName,
                    axis: .vertical
                )
                .lineLimit(1...3)
                .submitLabel(.done)
                .onChange(of: displayName) { _, newValue in
                    if newValue.contains(where: \.isNewline) {
                        let trimmed = newValue.hasSuffix("\n")
                            ? String(newValue.dropLast())
                            : newValue
                        displayName = trimmed
                            .components(separatedBy: .newlines)
                            .joined(separator: " ")
                    }
                }
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
                    "The name on your profile. Up to 80 characters."
                )
            }

            Section {

                TextField(
                    "username",
                    text: $username
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .font(RawdeaTypography.body)
                .accessibilityLabel("Username")
                .disabled(viewModel.isSaving)
                .onChange(of: username) { _, newValue in
                    if newValue != newValue.lowercased() {
                        username = newValue.lowercased()
                    }
                    viewModel.clearMessages()
                }

                if !Profile.isValidUsername(username) {
                    RawdeaInlineError(
                        message: "Use 3 to 24 letters, numbers or underscores."
                    )
                }

            } header: {

                Text("Username")

            } footer: {

                Text("Shown on your posts. Each username belongs to one person.")
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

    private func characterStatus(
        count: Int,
        limit: Int
    ) -> some View {
        RawdeaCharacterLimitText(count: count, limit: limit)
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
            username: username,
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
