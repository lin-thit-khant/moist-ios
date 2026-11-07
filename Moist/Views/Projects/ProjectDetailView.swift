//
//  ProjectDetailView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//

import SwiftUI

struct ProjectDetailView: View {
    
    let project: Project
    let projects: [Project]
    
    @StateObject private var viewModel = FeedViewModel()
    
    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView("Loading projects...")
                
            } else if let error = viewModel.errorMessage,
                      viewModel.posts.isEmpty {
                
                VStack(spacing: 12) {
                    Text("Couldn't load posts")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.loadPosts(
                                projectId: project.id
                            )
                        }
                    }
                }
                .padding()
                
            } else if viewModel.posts.isEmpty {
                ContentUnavailableView(
                    "An unfinished beginning",
                    systemImage: "text.bubble",
                    description: Text(
                        "Move a thought here whenever you're ready."
                    )
                )
                
            } else {
                List {
                    ForEach(viewModel.posts) { post in
                        PostRowView(
                            post: post,
                            currentUserId: project.userId,
                            onEdit: {
                                selectedPostForEditing = post
                            },
                            onDelete: {
                                Task {
                                    await viewModel.deletePost(
                                        postId: post.id
                                    )
                                }
                            },
                            onMove: {
                                selectedPostForMoving = post
                            }
                        )
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.loadPosts(
                        projectId: project.id
                    )
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: project.id) {
            await viewModel.loadPosts(
                projectId: project.id
            )
        }
        .sheet(item: $selectedPostForEditing) { post in
            EditPostView(
                post: post,
                viewModel: viewModel
            )
        }
        .sheet(item: $selectedPostForMoving) { post in
            MovePostToProjectView(
                post: post,
                projects: projects,
                onMoved: {
                    await viewModel.loadPosts(
                        projectId: project.id
                    )
                }
            )
        }
        .alert(
            "Couldn't delete post",
            isPresented: Binding(
                get: {
                    viewModel.deletionErrorMessage != nil
                }, set: { isPresented in
                    if !isPresented {
                        viewModel.clearDeletionError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.clearDeletionError()
            }
        } message: {
            Text(viewModel.deletionErrorMessage ?? "")
        }
    }
}
