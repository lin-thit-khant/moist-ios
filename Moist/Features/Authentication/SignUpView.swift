//
//  SignUpView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct SignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    
    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isFormValid: Bool {
        normalizedEmail.contains("@") &&
        normalizedEmail.contains(".") &&
        password.count >= 8
    }
    
    var body: some View {
        Form {
            Section("Your account") {
                TextField("Email address", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                HStack {
                    Group {
                        if isPasswordVisible {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(
                            systemName: isPasswordVisible
                            ? "eye.slash"
                            : "eye"
                        )
                    }
                    .accessibilityLabel(
                        isPasswordVisible ? "Hide password" : "Show password"
                    )
                }
                
                Text("Use at least 8 characters for your password.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let errorMessage = authViewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            
            if let statusMessage = authViewModel.statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Button {
                    Task {
                        await authViewModel.signUp(
                            email: normalizedEmail,
                            password: password
                        )
                    }
                } label: {
                    HStack {
                        Spacer()
                        
                        if authViewModel.isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        
                        Text(
                            authViewModel.isLoading
                            ? "Creating account..."
                            : "Create account"
                        )
                        
                        Spacer()
                    }
                }
                .disabled(!isFormValid || authViewModel.isLoading)
            }
        }
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
