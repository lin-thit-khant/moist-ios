//
//  WelcomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                Text("Rawdea")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A quiet space for unfinished ideas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                NavigationLink("Create account") {
                    SignUpView(authViewModel: authViewModel)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                NavigationLink("Log in") {
                    LoginView(authViewModel: authViewModel)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }
}
