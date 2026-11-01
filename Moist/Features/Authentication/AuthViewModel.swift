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
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    @Published private(set) var callBackError: String?
    private var isHandlingPasswordRecovery = false
    private let passwordRecoveryPendingKey = "moist.passwordRecoveryPending"
    
    enum AuthState {
        case loading
        case signedOut
        case signedIn
        case passwordRecovery
    }
    
    @Published private(set) var state: AuthState = .loading
    
    private var authStateTask: Task<Void, Never>?
    
    init() {
        observeAuthState()
    }
    
    func signUp(email: String, password: String) async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            let response = try await SupabaseManager.client.auth.signUp(
                email: email,
                password: password,
                redirectTo: URL(string: "moist://login-callback")
            )
            
            if response.session == nil {
                statusMessage = "Account created. Check your email to confirm your account."
            } else {
                statusMessage = "Your account has been created."
            }
        } catch {
            errorMessage = "Sign-up failed. Please check your details and try again."
        }
    }
    
    func signIn(email: String, password: String) async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await SupabaseManager.client.auth.signIn(
                email: email,
                password: password
            )
        } catch {
            errorMessage = "Login failed. Check your email password, then try again."
        }
    }
    
    func signOut() async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await SupabaseManager.client.auth.signOut(scope: .local)
        } catch {
            errorMessage = "We couldn't log you out. Please try again."
        }
    }
    
    func resetPassword(email: String) async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await SupabaseManager.client.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "moist://login-callback")
            )
            
            UserDefaults.standard.set(
                true,
                forKey: passwordRecoveryPendingKey
            )
            
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
    
    func updatePassword(newPassword: String) async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await SupabaseManager.client.auth.update(
                user: UserAttributes(password: newPassword)
            )
            
            isHandlingPasswordRecovery = false
            
            UserDefaults.standard.removeObject(
                forKey: passwordRecoveryPendingKey
            )
            
            state = .signedIn
            statusMessage = "Your password has been updated successfully."
        } catch {
            errorMessage = "We couldn't update your password. Please try again."
        }
    }
    
    func handleAuthCallback(url: URL) async {
        callBackError = nil
        
        let isPendingRecovery = UserDefaults.standard.bool(
            forKey: passwordRecoveryPendingKey
        )
        
        guard url.scheme == "moist",
              url.host == "login-callback" else {
            return
        }
        
        if isPendingRecovery {
            isHandlingPasswordRecovery = true
            state = .passwordRecovery
        }
        
        SupabaseManager.client.auth.handle(url)
    }
    
    func clearCallbackError() {
        callBackError = nil
    }
    
    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            for await (event, session) in
                    SupabaseManager.client.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                
                print("Supabase auth event: \(event)")
                print("Has session: \(session != nil)")

                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .passwordRecovery:
                    if self.isHandlingPasswordRecovery {
                        self.state = .passwordRecovery
                    } else {
                        self.state = session == nil ? .signedOut : .signedIn
                    }
                case .signedOut:
                    self.state = .signedOut
                default:
                    break
                }

                print("Moist AuthState: \(self.state)")
            }
        }
    }
}
