//
//  RawdeaAuthFormView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//

import SwiftUI

// MARK: - Authentication mode

enum RawdeaAuthFormMode {

    case login
    case signUp
    case forgotPassword
    case resetPassword

    var navigationTitle: String {

        switch self {

        case .login:
            return "Log in"

        case .signUp:
            return "Create account"

        case .forgotPassword:
            return "Forgot Password"

        case .resetPassword:
            return "Reset Password"
        }
    }

    var heading: String {

        switch self {

        case .login:
            return "Welcome back"

        case .signUp:
            return "Make space for your ideas"

        case .forgotPassword:
            return "Reset your password"

        case .resetPassword:
            return "Create a new password"
        }
    }

    var message: String {

        switch self {

        case .login:

            return "Log in to continue writing and exploring."

        case .signUp:

            return "Create your Rawdea account and start sharing your thoughts."

        case .forgotPassword:

            return "Enter the email address associated with your account."

        case .resetPassword:

            return "Choose a new password for your Rawdea account."
        }
    }

    var buttonTitle: String {

        switch self {

        case .login:
            return "Log in"

        case .signUp:
            return "Create account"

        case .forgotPassword:
            return "Send reset link"

        case .resetPassword:
            return "Update password"
        }
    }
}

// MARK: - Shared form

struct RawdeaAuthFormView: View {

    @ObservedObject var authViewModel:
        AuthViewModel

    let mode: RawdeaAuthFormMode

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - Validation

    private var normalizedEmail: String {

        email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var isEmailValid: Bool {

        normalizedEmail.contains("@") &&
        normalizedEmail.contains(".")
    }

    private var isNewPasswordValid: Bool {

        password.count >= 8
    }

    private var passwordsMatch: Bool {

        !password.isEmpty &&
        password == confirmPassword
    }

    private var isFormValid: Bool {

        switch mode {

        case .login:

            return isEmailValid &&
                !password.isEmpty

        case .signUp:

            return isEmailValid &&
                isNewPasswordValid

        case .forgotPassword:

            return isEmailValid

        case .resetPassword:

            return isNewPasswordValid &&
                passwordsMatch
        }
    }

    private var canSubmit: Bool {

        isFormValid &&
        !authViewModel.isLoading
    }

    // MARK: - Body

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.lg
            ) {

                RawdeaAuthHeading(
                    title: mode.heading,
                    message: mode.message
                )

                fields
                    .disabled(
                        authViewModel.isLoading
                    )

                validationMessages

                if let error =
                    authViewModel.errorMessage {

                    RawdeaInlineError(
                        message: error
                    )
                }

                if let status =
                    authViewModel.statusMessage {

                    RawdeaAuthStatus(
                        message: status
                    )
                }

                RawdeaPrimaryButton(
                    mode.buttonTitle,
                    isLoading:
                        authViewModel.isLoading,
                    isEnabled:
                        canSubmit
                ) {

                    Task {
                        await submit()
                    }
                }

                additionalActions
            }
            .frame(maxWidth: 480)
            .padding(
                .horizontal,
                RawdeaSpacing.screenInset
            )
            .padding(
                .vertical,
                RawdeaSpacing.xl
            )
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle(
            mode.navigationTitle
        )
        .navigationBarTitleDisplayMode(.inline)

        // Prevent leaving an in-progress
        // authentication request.

        .navigationBarBackButtonHidden(
            authViewModel.isLoading
        )

        .onAppear {

            authViewModel.clearMessages()
        }

        .onChange(of: email) { _, _ in

            authViewModel.clearMessages()
        }

        .onChange(of: password) { _, _ in

            authViewModel.clearMessages()
        }

        .onChange(of: confirmPassword) { _, _ in

            authViewModel.clearMessages()
        }
    }

    // MARK: - Fields

    @ViewBuilder
    private var fields: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.md
        ) {

            if mode != .resetPassword {

                RawdeaEmailField(
                    email: $email
                )
            }

            if mode != .forgotPassword {

                RawdeaPasswordField(
                    title:
                        mode == .resetPassword
                        ? "New password"
                        : "Password",
                    password: $password,
                    isNewPassword:
                        mode == .signUp ||
                        mode == .resetPassword
                )
            }

            if mode == .resetPassword {

                RawdeaPasswordField(
                    title: "Confirm new password",
                    password: $confirmPassword,
                    isNewPassword: true
                )
            }
        }
    }

    // MARK: - Validation messages

    @ViewBuilder
    private var validationMessages: some View {

        if mode == .signUp ||
           mode == .resetPassword {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.xs
            ) {

                Text(
                    "Use at least 8 characters for your password."
                )
                .font(RawdeaTypography.metadata)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )

                if !password.isEmpty &&
                   !isNewPasswordValid {

                    RawdeaInlineError(
                        message:
                            "Your password is too short."
                    )
                }

                if mode == .resetPassword,
                   !confirmPassword.isEmpty,
                   !passwordsMatch {

                    RawdeaInlineError(
                        message:
                            "Passwords do not match."
                    )
                }
            }
        }
    }

    // MARK: - Additional actions

    @ViewBuilder
    private var additionalActions: some View {

        if mode == .login {

            NavigationLink {

                ForgotPasswordView(
                    authViewModel: authViewModel
                )

            } label: {

                Text("Forgot password?")
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.accent
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                authViewModel.isLoading
            )
        }

        if mode == .signUp {

            NavigationLink {

                SafetyInformationView()

            } label: {

                Text("Read our Community Guidelines")
                    .font(
                        RawdeaTypography.metadata
                    )
                    .foregroundStyle(
                        RawdeaPalette.accent
                    )
                    .multilineTextAlignment(.center)
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                authViewModel.isLoading
            )
        }
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {

        guard canSubmit else {
            return
        }

        switch mode {

        case .login:

            await authViewModel.signIn(
                email: normalizedEmail,
                password: password
            )

        case .signUp:

            await authViewModel.signUp(
                email: normalizedEmail,
                password: password
            )

        case .forgotPassword:

            await authViewModel.resetPassword(
                email: normalizedEmail
            )

        case .resetPassword:

            await authViewModel.updatePassword(
                newPassword: password
            )
        }
    }
}
