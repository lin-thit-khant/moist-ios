//
//  ForgotPasswordView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct ForgotPasswordView: View {
    
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    
    private var normalizeEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isEmailValid: Bool {
        normalizeEmail.contains("@") &&
        normalizeEmail.contains(".")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Reset your password")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Enter the email address associated with your account.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            TextField("Email address", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .disabled(authViewModel.isLoading)
            
            if let statusMessage = authViewModel.statusMessage {
                Text(statusMessage)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            }
            
            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    await authViewModel.resetPassword(
                        email: normalizeEmail
                    )
                }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                    }
                    
                    Text(
                        authViewModel.isLoading
                        ? "Sending..."
                        : "Send reset link"
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isEmailValid || authViewModel.isLoading)
            
            Spacer()
        }
        .padding(24)
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}
