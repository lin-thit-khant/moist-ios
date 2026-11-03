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
    @StateObject private var postsViewModel = AuthorPostsViewModel()
    
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
                    VStack(spacing: 20) {
                        ProfileContentView(profile: profile)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            
                            Text("Posts")
                                .font(.headline)
                            
                            if postsViewModel.isLoading {
                                
                                ProgressView("Loading posts")
                                    .frame(maxWidth: .infinity)
                                
                            } else if let errorMessage = postsViewModel.errorMessage {
                                
                                VStack(spacing: 12) {
                                    
                                    Text("Couldn't load posts")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Try Again") {
                                        Task {
                                            await postsViewModel.loadPosts(userId: userId)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .frame(maxWidth: .infinity)
                            } else if postsViewModel.posts.isEmpty {
                                
                                Text("No posts yet")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                
                                LazyVStack(spacing: 0) {
                                    
                                    ForEach(postsViewModel.posts) { post in
                                        
                                        PostRowView(post: post)
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
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
        .task(id: userId) {
            await postsViewModel.loadPosts(userId: userId)
        }
    }
}
