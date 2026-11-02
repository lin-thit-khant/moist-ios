//
//  LoginView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct LoginView: View {
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
        !password.isEmpty
    }
    
    var body: some View {
        Form {
            Section("Welcome back") {
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
                    .textContentType(.password)
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
            }
            
            if let errorMessage = authViewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            
            NavigationLink("Forgot password?") {
                ForgotPasswordView(authViewModel: authViewModel)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            Section {
                Button {
                    Task {
                        await authViewModel.signIn(
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
                            ? "Loggin in..."
                            : "Log in"
                        )
                        
                        Spacer()
                    }
                }
                .disabled(!isFormValid || authViewModel.isLoading)
            }
        }
        .navigationTitle("Log in")
        .navigationBarTitleDisplayMode(.inline)
    }
}


