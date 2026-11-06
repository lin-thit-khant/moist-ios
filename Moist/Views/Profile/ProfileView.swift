//
//  ProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import SwiftUI

struct ProfileView: View {
    
    @StateObject private var viewModel = ProfileViewModel()
    
    @StateObject private var postsViewModel = FeedViewModel()
    
    @State private var selectedPostForEditing: Post?
    
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
                    
                    Text("Couldn't load your profile")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.loadProfile()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let profile = viewModel.profile {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        ProfileContentView(profile: profile)
                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        NavigationLink {
                            EditProfileView(viewModel: viewModel, profile: profile)
                        } label: {
                            Text("Edit Profile")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text("Your posts")
                                .font(.headline)
                            
                            if postsViewModel.isLoading && postsViewModel.posts.isEmpty {
                                
                                ProgressView("Loading posts...")
                                
                            } else if let errorMessage = postsViewModel.errorMessage {
                                
                                Text(errorMessage)
                                    .foregroundStyle(.secondary)
                                
                                Button("Try Again") {
                                    Task {
                                        await postsViewModel.loadPosts(userId: profile.id)
                                    }
                                }
                                
                            } else if postsViewModel.posts.isEmpty {
                                
                                Text("Your thoughts will appear here.")
                                    .foregroundStyle(.secondary)
                                
                            } else {
                                
                                LazyVStack(spacing: 0) {
                                    
                                    ForEach(postsViewModel.posts) { post in
                                        
                                        PostRowView(
                                            post: post,
                                            currentUserId: profile.id,
                                            onEdit: {
                                                selectedPostForEditing = post
                                            },
                                            onDelete: {
                                                Task {
                                                    await postsViewModel.deletePost(
                                                        postId: post.id
                                                    )
                                                }
                                            }
                                        )
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                }
                .task(id: profile.id) {
                    await postsViewModel.loadPosts(userId: profile.id)
                }
                .refreshable {
                    await viewModel.loadProfile()
                    
                    if let profile = viewModel.profile {
                        await postsViewModel.loadPosts(userId: profile.id)
                    }
                }
            } else {
                ProgressView("Preparing profile...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
        }
        .sheet(item: $selectedPostForEditing) { post in
            EditPostView(
                post: post,
                viewModel: postsViewModel
            )
        }
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: {
                    postsViewModel.deletionErrorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        postsViewModel.clearDeletionError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                postsViewModel.clearDeletionError()
            }
        } message: {
            Text(postsViewModel.deletionErrorMessage ?? "")
        }
    }
}
