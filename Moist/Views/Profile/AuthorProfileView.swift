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
    
    @StateObject private var followViewModel = UserFollowViewModel()
    
    var body: some View {
        
        Group {

            if viewModel.isLoading && viewModel.profile == nil {

                ProgressView("Loading profile...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                

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
                            await viewModel.loadProfile(
                                userId: userId
                            )
                            
                            await followViewModel.load(
                                userId: userId
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            } else if let profile = viewModel.profile {

                ScrollView {
                    
                    VStack(spacing: 20) {
                        
                        // Existing profile header
                        
                        ProfileContentView(profile: profile)
                        
                        // New follow section
                        
                        VStack(spacing: 12) {
                            
                            if followViewModel.isLoading {
                                
                                ProgressView("Loading follows...")
                                
                            } else if followViewModel.hasLoaded {
                                
                                HStack(spacing: 24) {
                                    
                                    VStack(spacing: 4) {
                                        
                                        Text(
                                            "\(followViewModel.followerCount)"
                                        )
                                        .fontWeight(.semibold)
                                        
                                        Text("Followers")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        
                                        Text(
                                            "\(followViewModel.followingCount)"
                                        )
                                        .fontWeight(.semibold)
                                        
                                        Text("Following")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                if !followViewModel.isOwnProfile {
                                    
                                    Button {
                                        
                                        Task {
                                            await followViewModel.toggleFollow(
                                                userId: userId
                                            )
                                        }
                                        
                                    } label: {
                                        
                                        HStack(spacing: 8) {
                                            
                                            if followViewModel.isUpdating {
                                                ProgressView()
                                            }
                                            
                                            Label(
                                                followViewModel.isFollowing
                                                ? "Following"
                                                : "Follow",
                                                systemImage:
                                                    followViewModel.isFollowing
                                                ? "checkmark"
                                                : "person.badge.plus"
                                            )
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(followViewModel.isUpdating)
                                }
                            }
                            
                            if let error = followViewModel.errorMessage {
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                
                                if !followViewModel.hasLoaded {
                                    
                                    Button("Retry Follow Status") {
                                        Task {
                                            await followViewModel.load(
                                                userId: userId
                                            )
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider()

                        PublicProfileSectionsView(
                            userId: userId
                        )
                    }
                    .padding()
                }

            } else {
                
                ProgressView("Preparing profile...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userId) {
            await viewModel.loadProfile(
                userId: userId
            )
            
            await followViewModel.load(
                userId: userId
            )
        }
    }
}
