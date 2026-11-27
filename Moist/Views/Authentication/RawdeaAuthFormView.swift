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
            return "Create your account"

        case .forgotPassword:
            return "Reset your password"

        case .resetPassword:
            return "Create a new password"
        }
    }

    var message: String {

        switch self {

        case .login:

            return "Log in with your email."

        case .signUp:

            return "Use your email. You can change your username later."

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

    // Log in and Create account switch in place,
    // so Back always returns to the welcome screen.

    @State private var mode: RawdeaAuthFormMode

    init(
        authViewModel: AuthViewModel,
        mode: RawdeaAuthFormMode
    ) {
        self.authViewModel = authViewModel
        _mode = State(initialValue: mode)
    }

    /// Log in and Create account use the welcome screen's style.
    private var isEntry: Bool {

        mode == .login || mode == .signUp
    }

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

        GeometryReader { geometry in

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.lg
                ) {

                    heading

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
                            canSubmit,
                        look:
                            isEntry ? .auth : .standard
                    ) {

                        Task {
                            await submit()
                        }
                    }

                    additionalActions

                    if isEntry {

                        Spacer(minLength: 0)

                        entryFooter
                    }
                }
                .frame(maxWidth: 480)
                .padding(
                    .horizontal,
                    isEntry
                    ? RawdeaSpacing.authInset
                    : RawdeaSpacing.screenInset
                )
                .padding(
                    .vertical,
                    isEntry
                    ? RawdeaSpacing.xs
                    : RawdeaSpacing.xl
                )
                .frame(
                    minHeight:
                        isEntry ? geometry.size.height : nil,
                    alignment: .top
                )
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(
            (
                isEntry
                ? RawdeaPalette.authCanvas
                : RawdeaPalette.canvas
            )
            .ignoresSafeArea()
        )
        .navigationTitle(
            isEntry ? "" : mode.navigationTitle
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

    // MARK: - Heading

    @ViewBuilder
    private var heading: some View {

        if isEntry {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.xs
            ) {

                RawdeaAuthHeadline(
                    mode.heading,
                    size: 28,
                    largest: 56
                )

                Text(mode.message)
                    .font(RawdeaTypography.body)
                    .foregroundStyle(
                        RawdeaPalette.authSecondaryText
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

        } else {

            RawdeaAuthHeading(
                title: mode.heading,
                message: mode.message
            )
        }
    }

    // MARK: - Switch and legal

    private var entryFooter: some View {

        VStack(spacing: RawdeaSpacing.xxs) {

            Button {

                // A password typed for one mode
                // should not carry into the other.
                password = ""
                mode = mode == .login ? .signUp : .login
                authViewModel.clearMessages()

            } label: {

                RawdeaAuthSwitchLabel(
                    prompt:
                        mode == .login
                        ? "New here?"
                        : "Have an account?",
                    action:
                        mode == .login
                        ? "Create account"
                        : "Log in"
                )
            }
            .buttonStyle(.plain)

            if mode == .signUp {

                RawdeaAuthLegalLink()
            }
        }
        .disabled(authViewModel.isLoading)
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
                    email: $email,
                    isBoxed: isEntry
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
                        mode == .resetPassword,
                    isBoxed: isEntry
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
                    .underline()
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.authText
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

        if mode == .resetPassword {

            Button("Cancel and Log Out") {

                Task {

                    await authViewModel.signOut()
                }
            }
            .font(RawdeaTypography.secondary)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .frame(
                maxWidth: .infinity,
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .disabled(authViewModel.isLoading)
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
