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
    
    @Environment(\.scenePhase) private var scenePhase
    
    // Existing normal feed
    
    @StateObject private var feedViewModel = FeedViewModel()
    
    // New personalized Following feed
    
    @StateObject private var followingFeedViewModel = FollowingFeedViewModel()
    @StateObject private var notificationsViewModel = NotificationsViewModel()
    
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

                Task {

                    await notificationsViewModel.refreshUnreadCount()
                }
            }
            
            .task {
                await notificationsViewModel.refreshUnreadCount()
            }
            
            // Refresh when Rawdea returns from
            // the background to the foreground.
            
            
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                Task {
                    await notificationsViewModel
                        .refreshUnreadCount()

                    switch selectedFeed {
                    case .all:
                        await feedViewModel.reloadVisiblePosts()

                    case .following:
                        await followingFeedViewModel
                            .reloadVisiblePosts()
                    }
                }
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
                
                
                // MARK: - Search and Discovery

                ToolbarItem(placement: .topBarLeading) {

                    NavigationLink {

                        DiscoveryView()

                    } label: {

                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Explore Rawdea")
                }

                
                
                // MARK: - Notifications

                ToolbarItem(placement: .topBarTrailing) {

                    NavigationLink {

                        NotificationsView(
                            viewModel: notificationsViewModel
                        )

                    } label: {

                        ZStack(alignment: .topTrailing) {

                            Image(systemName: "bell")
                                .frame(
                                    width: 28,
                                    height: 28
                                )

                            if notificationsViewModel.unreadCount > 0 {

                                Text(
                                    notificationsViewModel.unreadCount > 99
                                    ? "99+"
                                    : "\(notificationsViewModel.unreadCount)"
                                )
                                .font(
                                    .system(
                                        size: 10,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Color.red,
                                    in: Capsule()
                                )
                                .offset(x: 10, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel(
                        "Notifications, \(notificationsViewModel.unreadCount) unread"
                    )
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
