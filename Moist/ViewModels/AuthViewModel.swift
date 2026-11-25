//
//  AuthViewModel.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {

    @Published private(set) var isLoading = false
    @Published private(set) var sessionUserId: UUID?
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var callBackError: String?

    enum AuthState {

        case loading
        case signedOut
        case signedIn
        case passwordRecovery
    }

    @Published private(set) var state:
        AuthState = .loading

    private var authStateTask: Task<Void, Never>?

    private var isHandlingAuthCallback = false

    // This stores the identity of a verified
    // recovery session, not a password or token.

    private let recoveryUserKey =
        "rawdea.verifiedRecoveryUserId"

    init() {

        // Remove the obsolete flag that could
        // incorrectly classify a later callback.

        UserDefaults.standard.removeObject(
            forKey: "moist.passwordRecoveryPending"
        )

        observeAuthState()
    }

    // MARK: - Sign up

    func signUp(
        email: String,
        password: String
    ) async {

        guard !isLoading else {
            return
        }

        errorMessage = nil
        statusMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {

            let response =
                try await SupabaseManager.client.auth
                    .signUp(
                        email: email,
                        password: password,
                        redirectTo: URL(
                            string:
                                "rawdea://login-callback"
                        )
                    )

            if let session = response.session {

                clearRecoveryState()

                applySession(session)

                statusMessage =
                    "Your account has been created."

            } else {

                statusMessage =
                    "Account created. Check your email to confirm your account."
            }

        } catch {

            errorMessage =
                "Sign-up failed. Please check your details and try again."
        }
    }

    // MARK: - Sign in

    func signIn(
        email: String,
        password: String
    ) async {

        guard !isLoading else {
            return
        }

        errorMessage = nil
        statusMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {

            let session =
                try await SupabaseManager.client.auth
                    .signIn(
                        email: email,
                        password: password
                    )

            clearRecoveryState()

            applySession(session)

        } catch {

            errorMessage =
                "Login failed. Check your email and password, then try again."
        }
    }

    // MARK: - Sign out

    func signOut() async {

        guard !isLoading else {
            return
        }

        errorMessage = nil
        statusMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {

            try await SupabaseManager.client.auth
                .signOut(scope: .local)

            applySession(nil)

        } catch {

            errorMessage =
                "We couldn't log you out. Please try again."
        }
    }

    // MARK: - Request password recovery

    func resetPassword(email: String) async {

        guard !isLoading else {
            return
        }

        errorMessage = nil
        statusMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {

            try await SupabaseManager.client.auth
                .resetPasswordForEmail(
                    email,
                    redirectTo: URL(
                        string:
                            "rawdea://password-recovery"
                    )
                )

            // Requesting an email does not
            // establish a recovery session.

            statusMessage = """
            If an account exists for this email, \
            you'll receive a password reset link.
            """

        } catch {

            errorMessage = """
            We couldn't send the reset request. \
            Please try again later.
            """
        }
    }

    // MARK: - Update password

    func updatePassword(
        newPassword: String
    ) async {

        guard !isLoading,
              state == .passwordRecovery else {

            return
        }

        guard newPassword.count >= 8 else {

            errorMessage =
                "Your password must contain at least 8 characters."

            return
        }

        errorMessage = nil
        statusMessage = nil
        isLoading = true

        defer {
            isLoading = false
        }

        do {

            let session =
                try await SupabaseManager.client.auth
                    .session

            guard recoveryUserId ==
                    session.user.id.uuidString else {

                applySession(session)

                errorMessage =
                    "Your recovery session is no longer available."

                return
            }

            try await SupabaseManager.client.auth
                .update(
                    user: UserAttributes(
                        password: newPassword
                    )
                )

            clearRecoveryState()

            applySession(session)

            statusMessage =
                "Your password has been updated successfully."

        } catch {

            errorMessage =
                "We couldn't update your password. Please try again."
        }
    }

    // MARK: - Authentication callback

    func handleAuthCallback(url: URL) async {

        guard let route =
            RawdeaAuthCallbackRoute(url: url) else {

            return
        }

        guard !isHandlingAuthCallback else {
            return
        }

        guard !isLoading else {

            callBackError =
                "Another authentication request is in progress. Please try opening the link again."

            return
        }

        callBackError = nil
        errorMessage = nil
        statusMessage = nil

        isHandlingAuthCallback = true
        isLoading = true

        defer {

            isHandlingAuthCallback = false
            isLoading = false
        }

        do {

            // Wait for Supabase to validate
            // the callback and return a session.

            let session =
                try await SupabaseManager.client.auth
                    .session(from: url)

            switch route {

            case .login:

                clearRecoveryState()

            case .passwordRecovery:

                markRecoverySession(session)
            }

            applySession(session)

        } catch {

            // Never enter password recovery
            // based on an unsuccessful callback.

            let existingSession =
                try? await SupabaseManager.client.auth
                    .session

            applySession(existingSession)

            callBackError = """
            This authentication link couldn't be opened. \
            It may be invalid or expired. \
            Please request a new link.
            """
        }
    }

    // MARK: - Recovery state

    private var recoveryUserId: String? {

        UserDefaults.standard.string(
            forKey: recoveryUserKey
        )
    }

    private func markRecoverySession(
        _ session: Session
    ) {

        UserDefaults.standard.set(
            session.user.id.uuidString,
            forKey: recoveryUserKey
        )
    }

    private func clearRecoveryState() {

        UserDefaults.standard.removeObject(
            forKey: recoveryUserKey
        )
    }

    
    private func applySession(
        _ session: Session?
    ) {

        guard let session else {

            clearRecoveryState()

            sessionUserId = nil
            state = .signedOut

            return
        }

        // The signed-in interface belongs to
        // this authenticated user's identity.

        if sessionUserId != session.user.id {

            sessionUserId = session.user.id
        }

        if recoveryUserId ==
            session.user.id.uuidString {

            state = .passwordRecovery

        } else {

            clearRecoveryState()

            state = .signedIn
        }
    }


    // MARK: - Messages

    func clearMessages() {

        guard !isLoading else {
            return
        }

        errorMessage = nil
        statusMessage = nil
    }

    func clearCallbackError() {

        callBackError = nil
    }

    // MARK: - Observe Supabase authentication

    private func observeAuthState() {

        authStateTask = Task { [weak self] in

            for await (event, session) in
                SupabaseManager.client.auth
                    .authStateChanges {

                guard !Task.isCancelled else {
                    return
                }

                guard let self else {
                    return
                }

                // The callback handler decides
                // the destination after validation.

                guard !self.isHandlingAuthCallback else {
                    continue
                }

                switch event {

                case .initialSession,
                     .signedIn,
                     .tokenRefreshed:

                    self.applySession(session)

                case .passwordRecovery:

                    if let session {

                        self.markRecoverySession(
                            session
                        )

                        self.applySession(session)

                    } else {

                        self.applySession(nil)
                    }

                case .signedOut:

                    self.applySession(nil)

                default:

                    break
                }
            }
        }
    }
}
