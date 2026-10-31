//
//  AuthFlowView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import Foundation
import SwiftUI

struct AuthFlowView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView("Loading Moist...")
            case .signedOut:
                NavigationStack {
                    WelcomeView(authViewModel: authViewModel)
                }
            case .signedIn:
                HomeView(authViewModel: authViewModel)
            case .passwordRecovery:
                Text("Password recovery detected")
            }
        }
        .onOpenURL { url in
            Task {
                await authViewModel.handleAuthCallback(url: url)
            }
        }
        .alert(
            "Email confirmation",
            isPresented: Binding(
                get: { authViewModel.callBackError != nil },
                set: { isPresented in
                    if !isPresented {
                        authViewModel.clearCallbackError()
                    }
                }
            )) {
                Button("OK", role: .cancel) {
                    authViewModel.clearCallbackError()
                }
            } message: {
                Text(authViewModel.callBackError ?? "")
            }

    }
}
