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

    private var isValid: Bool {
        displayName.count <= 80 &&
        bio.count <= 160
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

                characterStatus(
                    count: displayName.count,
                    limit: 80
                )

            } header: {

                Text("Display name")

            } footer: {

                Text(
                    "This is the name people see on your posts and profile."
                )
            }

            Section {

                TextEditor(text: $bio)
                    .font(RawdeaTypography.body)
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Bio")

                characterStatus(
                    count: bio.count,
                    limit: 160
                )

            } header: {

                Text("Bio")

            } footer: {

                Text(
                    "Share a little about yourself and what you enjoy creating."
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

        .safeAreaInset(
            edge: .bottom,
            spacing: 0
        ) {

            saveFooter
        }

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

        HStack(spacing: RawdeaSpacing.xs) {

            if count > limit {

                Label(
                    "Over character limit",
                    systemImage:
                        "exclamationmark.circle"
                )
                .foregroundStyle(
                    RawdeaPalette.danger
                )

            } else {

                Text(
                    "Maximum \(limit) characters"
                )
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
            }

            Spacer(minLength: 0)

            Text("\(count)/\(limit)")
                .foregroundStyle(
                    count > limit
                    ? RawdeaPalette.danger
                    : RawdeaPalette.secondaryText
                )
        }
        .font(RawdeaTypography.caption)
        .accessibilityElement(
            children: .combine
        )
    }

    // MARK: - Save footer

    private var saveFooter: some View {

        VStack(spacing: 0) {

            Divider()
                .overlay(RawdeaPalette.divider)

            RawdeaPrimaryButton(
                "Save Changes",
                isLoading: viewModel.isSaving,
                isEnabled: canSave
            ) {

                Task {
                    await saveProfile()
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
                .ignoresSafeArea(edges: .bottom)
        )
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
