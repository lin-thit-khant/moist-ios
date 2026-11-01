//
//  ResetPasswordView.swift
//  Moist
//
//  Created by Lin Thit Khant on 31/10/2569 BE.
//

import SwiftUI

struct ResetPasswordView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isPasswordVisible = false
    
    private var passwordMatch: Bool {
        !newPassword.isEmpty &&
        newPassword == confirmPassword
    }
    
    private var isPasswordValid: Bool {
        newPassword.count >= 8
    }
    
    private var canUpdatePassword: Bool {
        isPasswordValid && passwordMatch
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create a new password")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Choose a new password for your Moist account.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Group {
                if isPasswordVisible {
                    TextField("New Password", text: $newPassword)
                } else {
                    SecureField("New Password", text: $newPassword)
                }
            }
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .disabled(authViewModel.isLoading)
            
            Group {
                if isPasswordVisible {
                    TextField("Confirm new password", text: $confirmPassword)
                } else {
                    SecureField("Confirm new password", text: $confirmPassword)
                }
            }
            .textContentType(.newPassword)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .disabled(authViewModel.isLoading)
            
            Toggle("Show passwords", isOn: $isPasswordVisible)
                .disabled(authViewModel.isLoading)
        
            if newPassword.isEmpty || isPasswordValid {
                EmptyView()
            } else {
                Text("Password must contain at least 8 characters.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
            if !confirmPassword.isEmpty && !passwordMatch {
                Text("Passwords do not match.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            
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
                    await authViewModel.updatePassword(
                        newPassword: newPassword
                    )
                }
            } label: {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                    }
                    
                    Text(
                        authViewModel.isLoading
                        ? "Updating..."
                        : "Update password"
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                !canUpdatePassword ||
                authViewModel.isLoading
            )
            
            Spacer()
        }
        .padding(24)
        .navigationTitle("Reset Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}
