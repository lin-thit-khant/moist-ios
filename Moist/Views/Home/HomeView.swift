//
//  HomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI
import Supabase

struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    @StateObject private var feedViewModel = FeedViewModel()
    
    @State private var isShowingCreatePost = false
    @State private var recentlyCreatedPost: Post?
    @State private var currentUserId: UUID?
    
    var body: some View {
        
        NavigationStack {
            
            VStack(spacing: 12) {
                
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
            }
            .onAppear {
                SupabaseManager.debugConfiguration()
            }
            .task {
                do {
                    let user = try await SupabaseManager.client.auth.session.user
                    
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
            .sheet(isPresented: $isShowingCreatePost) {
                
                CreatePostView { post in
                    recentlyCreatedPost = post
                    
                    feedViewModel.addPost(post)
                }
            }
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
