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
    
    enum AuthState {
        case loading
        case signedOut
        case signedIn
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
                password: password
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
    
    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            for await (event, session) in
                    SupabaseManager.client.auth.authStateChanges {
                guard !Task.isCancelled else { return }
                guard let self else { return }
                
                switch event {
                case .initialSession, .signedIn, .signedOut, .tokenRefreshed:
                    self.state = session == nil ? .signedOut : .signedIn
                    
                default: break
                }
            }
        }
    }
}
