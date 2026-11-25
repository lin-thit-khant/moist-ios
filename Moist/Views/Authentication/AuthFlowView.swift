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

                VStack(
                    spacing: RawdeaSpacing.md
                ) {

                    Text("Rawdea")
                        .font(
                            RawdeaTypography.screenTitle
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )

                    ProgressView(
                        "Loading Rawdea..."
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )

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

                NavigationStack {

                    ResetPasswordView(
                        authViewModel: authViewModel
                    )
                }
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )

        // Preserve the existing deep-link flow.

        .onOpenURL { url in

            Task {

                await authViewModel
                    .handleAuthCallback(url: url)
            }
        }

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

