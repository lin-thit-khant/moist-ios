//
//  AuthorProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct AuthorProfileView: View {

    let userId: UUID

    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        Group {

            if viewModel.isLoading && viewModel.profile == nil {

                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.profile == nil {

                VStack(spacing: 16) {

                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)

                    Text("Couldn't load this profile")
                        .font(.headline)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        Task {
                            await viewModel.loadProfile(userId: userId)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            } else if let profile = viewModel.profile {

                ScrollView {
                    ProfileContentView(profile: profile)
                        .padding()
                }

            } else {

                ProgressView("Preparing profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userId) {
            await viewModel.loadProfile(userId: userId)
        }
    }
}
