//
//  AuthFlowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//


import Foundation
import SwiftUI

struct AuthFlowView: View {

    @StateObject private var authViewModel =
        AuthViewModel()

    var body: some View {

        Group {

            switch authViewModel.state {

            case .loading:

                ProgressView("Loading Rawdea...")

            case .signedOut:

                NavigationStack {
                    WelcomeView(
                        authViewModel: authViewModel
                    )
                }

            case .signedIn:

                RawdeaMainTabView(
                    authViewModel: authViewModel
                )

            case .passwordRecovery:

                ResetPasswordView(
                    authViewModel: authViewModel
                )
            }
        }

        // Preserve existing password-recovery
        // and authentication deep-link handling.
        .onOpenURL { url in

            Task {
                await authViewModel
                    .handleAuthCallback(url: url)
            }
        }

        // Preserve the existing callback alert.
        .alert(
            "Authentication",
            isPresented: Binding(
                get: {
                    authViewModel.callBackError != nil
                },
                set: { presented in

                    if !presented {
                        authViewModel.clearCallbackError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                authViewModel.clearCallbackError()
            }

        } message: {

            Text(
                authViewModel.callBackError ?? ""
            )
        }
    }
}
