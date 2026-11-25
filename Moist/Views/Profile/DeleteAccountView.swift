//
//  DeleteAccountView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import SwiftUI
import Supabase

struct DeleteAccountView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var confirmation = ""
    @State private var isDeleting = false
    @State private var showFinalConfirmation = false
    @State private var errorMessage: String?

    private var canDelete: Bool {
        confirmation == "DELETE" && !isDeleting
    }

    var body: some View {

        Form {

            Section("Permanent Account Deletion") {

                Label(
                    "This action cannot be undone.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.red)

                Text(
                    """
                    Deleting your account permanently removes access to Rawdea and deletes your account-owned posts, Projects, comments, and other related account data.

                    Limited moderation records may be retained for safety, security, or applicable legal requirements, as described in the privacy policy.
                    """
                )
                .font(.subheadline)
            }

            Section("Confirm Deletion") {

                Text(
                    "Type DELETE exactly to continue."
                )

                TextField(
                    "DELETE",
                    text: $confirmation
                )
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .disabled(isDeleting)
            }

            if let errorMessage {

                Section("Error") {

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {

                Button(
                    "Permanently Delete My Account",
                    role: .destructive
                ) {

                    showFinalConfirmation = true
                }
                .disabled(!canDelete)

                if isDeleting {

                    ProgressView("Deleting account...")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(isDeleting)
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isDeleting)

        .confirmationDialog(
            "Delete your Rawdea account permanently?",
            isPresented: $showFinalConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Delete Account",
                role: .destructive
            ) {

                Task {
                    await deleteAccount()
                }
            }

            Button("Cancel", role: .cancel) { }

        } message: {

            Text(
                "Your account and associated content cannot be restored."
            )
        }
    }

    @MainActor
    private func deleteAccount() async {

        guard canDelete else { return }

        isDeleting = true
        errorMessage = nil

        do {

            try await SafetyService()
                .deleteMyAccount()

        } catch {

            errorMessage = error.localizedDescription
            isDeleting = false
            return
        }

        // The server-side account deletion
        // has succeeded. Clear the cached
        // session from this device.

        do {

            try await SupabaseManager.client.auth
                .signOut(scope: .local)

        } catch {

            errorMessage = """
                Your account was deleted, but the app could not clear its local session. Close and reopen Rawdea.
                """
        }

        isDeleting = false
    }
}
