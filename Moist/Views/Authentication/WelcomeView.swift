//
//  WelcomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct WelcomeView: View {

    @ObservedObject var authViewModel:
        AuthViewModel

    @State private var notReadyProvider: String?

    var body: some View {

        GeometryReader { geometry in

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {

                    introduction

                    Spacer(
                        minLength: RawdeaSpacing.xl
                    )

                    if let error =
                        authViewModel.errorMessage {

                        RawdeaInlineError(
                            message: error
                        )
                        .padding(.bottom, RawdeaSpacing.sm)
                    }

                    choices
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(
                    .horizontal,
                    RawdeaSpacing.authInset
                )
                .padding(.top, RawdeaSpacing.md)
                .padding(.bottom, RawdeaSpacing.xxs)
                .frame(
                    minHeight: geometry.size.height
                )
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {

            ZStack {

                RawdeaPalette.authCanvas

                RawdeaAuthGrid()
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)

        .onAppear {

            authViewModel.clearMessages()
        }

        .alert(
            "Not available yet",
            isPresented: Binding(
                get: { notReadyProvider != nil },
                set: { if !$0 { notReadyProvider = nil } }
            )
        ) {

            Button("OK", role: .cancel) {}

        } message: {

            Text(
                RawdeaSocialSignIn.notReadyMessage(
                    notReadyProvider ?? ""
                )
            )
        }
    }

    // MARK: - Introduction

    private var introduction: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            RawdeaAuthMonoLabel("Rawdea · v1")
                .accessibilityLabel("Rawdea, version 1")

            RawdeaAuthHeadline(
                "Ideas worth following.",
                size: 40,
                largest: 64
            )
            .padding(.top, 46)

            Text("Keep up with people and the Projects they build.")
                .font(RawdeaTypography.body)
                .foregroundStyle(
                    RawdeaPalette.authSecondaryText
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .padding(.top, 14)

            HStack(spacing: RawdeaSpacing.sm) {

                RawdeaCellMark()

                RawdeaAuthMonoLabel("People\nProjects")
                    .accessibilityLabel("People and Projects")
            }
            .padding(.top, RawdeaSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sign-in choices

    private var choices: some View {

        VStack(spacing: 10) {

            Button {

                // Needs the Sign in with Apple capability.
                notReadyProvider = "Apple"

            } label: {

                RawdeaAuthChoiceLabel(
                    title: "Continue with Apple",
                    symbol: "apple.logo",
                    look: .apple
                )
            }

            NavigationLink {

                SignUpView(
                    authViewModel: authViewModel
                )

            } label: {

                RawdeaAuthChoiceLabel(
                    title: "Continue with email",
                    symbol: "envelope",
                    look: .email
                )
            }

            Button {

                guard RawdeaSocialSignIn.isGoogleReady else {
                    notReadyProvider = "Google"
                    return
                }

                Task {
                    await authViewModel.signInWithGoogle()
                }

            } label: {

                RawdeaAuthChoiceLabel(
                    title: "Continue with Google",
                    look: .outline,
                    isLoading: authViewModel.isLoading
                )
            }

            VStack(spacing: RawdeaSpacing.xxs) {

                NavigationLink {

                    LoginView(
                        authViewModel: authViewModel
                    )

                } label: {

                    RawdeaAuthSwitchLabel(
                        prompt: "Already have an account?",
                        action: "Log in"
                    )
                }

                RawdeaAuthLegalLink()
            }
        }
        .buttonStyle(.plain)
        .disabled(authViewModel.isLoading)
    }
}

#Preview {
    NavigationStack {
        WelcomeView(authViewModel: AuthViewModel())
    }
}
