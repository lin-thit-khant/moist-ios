//
//  HomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Moist!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("To be socially awkward.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("My Profile", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    Task {
                        await authViewModel.signOut()
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                        }
                        
                        Text(
                            authViewModel.isLoading
                            ? "Logging out..."
                            : "Log out"
                        )
                    }
                }
                .disabled(authViewModel.isLoading)
                
                if let errorMessage = authViewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Moist")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
