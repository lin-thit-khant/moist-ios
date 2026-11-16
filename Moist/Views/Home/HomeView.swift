//
//  HomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI
import Supabase

private enum HomeFeedTab: String {
    
    case all = "All Posts"
    case following = "Following"
}

struct HomeView: View {
    
    @ObservedObject var authViewModel: AuthViewModel
    
    // Existing normal feed
    
    @StateObject private var feedViewModel = FeedViewModel()
    
    // New personalized Following feed
    
    @StateObject private var followingFeedViewModel = FollowingFeedViewModel()
    
    @State private var selectedFeed: HomeFeedTab = .all
    
    // Existing state
    
    @State private var isShowingCreatePost = false
    @State private var recentlyCreatedPost: Post?
    @State private var currentUserId: UUID?
    
    var body: some View {
        
        NavigationStack {
            
            VStack(spacing: 12) {
                
                // MARK: - Feed Selector
                
                Picker(
                    "Feed",
                    selection: $selectedFeed
                ) {
                    
                    Text("All Posts")
                        .tag(HomeFeedTab.all)
                    
                    Text("Following")
                        .tag(HomeFeedTab.following)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // MARK: - Normal Feed
                
                if selectedFeed == .all {
                    
                    // Existing post publication banner
                    
                    if let post = recentlyCreatedPost {
                        
                        VStack(alignment: .leading, spacing: 6) {
                            
                            Text("Your post was published!")
                                .font(.headline)
                            
                            
                            Text(
                                feedViewModel.posts.first(where: { $0.id == post.id })?.content
                                ?? post.content
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Existing normal feed.
                    // Its loading and query behavior stay unchanged.
                    
                    FeedView(
                        viewModel: feedViewModel,
                        currentUserId: currentUserId
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: feedViewModel.posts.map(\.id)) { _, postIds in
                        
                        guard let recentlyCreatedPost else {
                            return
                        }
                        
                        if !postIds.contains(recentlyCreatedPost.id) {
                            self.recentlyCreatedPost = nil
                        }
                    }
                    
                    // MARK: - Personalized Following Feed
                    
                } else {
                    
                    FollowingFeedView(
                        viewModel: followingFeedViewModel
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }
            }
            
            // MARK: - Existing Configuration
            
            .onAppear {
                SupabaseManager.debugConfiguration()
            }
            
            // MARK: - Existing User Lookup
            
            .task {
                
                do {
                    
                    let user = try await SupabaseManager
                        .client.auth.session.user
                    
                    currentUserId = user.id
                    
                } catch {
                    
                    currentUserId = nil
                    
                    print("Couldn't retrieve current user: \(error)")
                }
            }
            .navigationTitle("Rawdea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                
                ToolbarItem(placement: .topBarLeading) {
                    
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    
                    Button {
                        isShowingCreatePost = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        Task {
                            await authViewModel.signOut()
                        }
                    } label: {
                        
                        HStack(spacing: 6) {
                            
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
                }
            }
            
            // MARK: - Existing Create Post Sheet
            
            .sheet(isPresented: $isShowingCreatePost) {
                
                CreatePostView { post in
                    recentlyCreatedPost = post
                    
                    feedViewModel.addPost(post)
                    
                    // After publishing, show the
                    // original feed containing the
                    // newly created post.
                    
                    selectedFeed = .all
                }
            }
            
            // MARK: - Existing Authentication Alert
            
            .alert(
                "Authentication",
                isPresented: Binding(
                    get: {
                        authViewModel.errorMessage != nil
                    },
                    set: { isPresented in
                        if !isPresented {
                            authViewModel.clearCallbackError()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    authViewModel.clearCallbackError()
                }
            } message: {
                
                Text(authViewModel.errorMessage ?? "")
            }
        }
    }
}
