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
    
    @StateObject private var projectsViewModel = ProjectsViewModel()
    
    @State private var isShowingCreateProject = false
    @State private var newProjectName = ""
    @State private var selectedPostForEditing: Post?
    @State private var selectedPostForMoving: Post?
    
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
                                            },
                                            onMove: {
                                                selectedPostForMoving = post
                                            }
                                        )
                                        
                                        Divider()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            
                            HStack {
                                Text("Projects")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button("New Project") {
                                    projectsViewModel.clearError()
                                    newProjectName = ""
                                    isShowingCreateProject = true
                                }
                            }
                            
                            if let errorMessage = projectsViewModel.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            if projectsViewModel.isLoading &&
                                projectsViewModel.projects.isEmpty {
                                
                                ProgressView("Loading projects...")
                                
                            } else if projectsViewModel.projects.isEmpty {
                                if projectsViewModel.errorMessage == nil {
                                    Text("Your Projects will appear here.")
                                        .foregroundStyle(.secondary)
                                }
                                
                            } else {
                                ForEach(projectsViewModel.projects) { project in
                                    NavigationLink {
                                        ProjectDetailView(
                                            project: project,
                                            projects: projectsViewModel.projects
                                        )
                                    } label: {
                                        HStack {
                                            Text(project.name)
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            Color(.secondarySystemBackground),
                                            in: RoundedRectangle(cornerRadius: 12)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sheet(isPresented: $isShowingCreateProject) {
                            NavigationStack {
                                Form {
                                    TextField("Project name", text: $newProjectName)
                                    
                                    if let errorMessage = projectsViewModel.errorMessage {
                                        Text(errorMessage)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .navigationTitle("New Project")
                                .navigationBarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Cancel") {
                                            isShowingCreateProject = false
                                        }
                                    }
                                    
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Create") {
                                            Task {
                                                let created = await projectsViewModel.creatProject(
                                                    name: newProjectName
                                                )
                                                
                                                if created {
                                                    isShowingCreateProject = false
                                                    newProjectName = ""
                                                }
                                            }
                                        }
                                        .disabled(
                                            newProjectName.trimmingCharacters(
                                                in: .whitespacesAndNewlines
                                            ).isEmpty ||
                                            newProjectName.count > 80 ||
                                            projectsViewModel.isCreating
                                        )
                                    }
                                }
                                .interactiveDismissDisabled(projectsViewModel.isCreating)
                            }
                        }
                    }
                    .padding()
                }
                .task(id: profile.id) {
                    await postsViewModel.loadPosts(userId: profile.id)
                    
                    await projectsViewModel.loadProjects(userId: profile.id)
                }
                .refreshable {
                    await viewModel.loadProfile()
                    
                    if let profile = viewModel.profile {
                        await postsViewModel.loadPosts(userId: profile.id)
                    }
                    
                    await projectsViewModel.loadProjects(userId: profile.id)
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
        .sheet(item: $selectedPostForMoving, content: { post in
            MovePostToProjectView(
                post: post,
                projects: projectsViewModel.projects,
                onMoved: {
                    if let userId = viewModel.profile?.id {
                        await postsViewModel.loadPosts(
                            userId: userId
                        )
                    }
                }
            )
        })
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
