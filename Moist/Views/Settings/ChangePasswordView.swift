//
//  ChangePasswordView.swift
//  Rawdea
//

import SwiftUI

/// Changes the password after checking the current one.
struct ChangePasswordView: View {

    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    private var canSave: Bool {
        !current.isEmpty &&
        new.count >= 8 &&
        new == confirmation &&
        !isSaving
    }

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: RawdeaSpacing.md) {

                RawdeaPasswordField(
                    title: "Current password",
                    password: $current
                )

                RawdeaPasswordField(
                    title: "New password",
                    password: $new,
                    isNewPassword: true
                )

                RawdeaPasswordField(
                    title: "Confirm new password",
                    password: $confirmation,
                    isNewPassword: true
                )

                Text("Use at least 8 characters.")
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)

                if !confirmation.isEmpty && new != confirmation {
                    RawdeaInlineError(message: "Passwords do not match.")
                }

                if let errorMessage {
                    RawdeaInlineError(message: errorMessage)
                }

                if didSave {
                    RawdeaAuthStatus(message: "Your password was changed.")
                }

                RawdeaPrimaryButton(
                    "Update password",
                    isLoading: isSaving,
                    isEnabled: canSave
                ) {
                    Task { await save() }
                }
            }
            .disabled(isSaving)
            .padding(RawdeaSpacing.screenInset)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .navigationTitle("Password")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSaving)
        .onChange(of: current) { _, _ in clearMessages() }
        .onChange(of: new) { _, value in
            if !value.isEmpty { clearMessages() }
        }
    }

    private func clearMessages() {
        errorMessage = nil
        if !current.isEmpty { didSave = false }
    }

    private func save() async {

        guard canSave else { return }

        isSaving = true
        errorMessage = nil
        didSave = false

        defer { isSaving = false }

        do {
            try await PasswordService()
                .changePassword(current: current, new: new)
            current = ""
            new = ""
            confirmation = ""
            didSave = true
        } catch PasswordService.Failure.wrongCurrentPassword {
            errorMessage = "Your current password isn't right."
        } catch {
            errorMessage = "Couldn't change your password. Try again."
        }
    }
}
