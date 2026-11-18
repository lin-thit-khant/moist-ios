//
//  FollowingView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 15/11/2569 BE.
//

import SwiftUI

struct FollowingView: View {
    
    @StateObject private var viewModel = FollowingViewModel()
    
    var body: some View {
            
        Group {
            if viewModel.isLoading &&
                viewModel.followedPeople.isEmpty &&
                viewModel.followedProjects.isEmpty {
                
                ProgressView("Loading following...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                
            } else if let error = viewModel.errorMessage,
                      viewModel.followedPeople.isEmpty &&
                        viewModel.followedProjects.isEmpty {
                
                VStack(spacing: 16) {
                    
                    ContentUnavailableView(
                        "Couln't load following",
                        systemImage: "person.2",
                        description: Text(error)
                    )
                    
                    Button("Try Again") {
                        Task {
                            await viewModel.loadFollowing()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
            } else {
                
                List {
                    
                    Section("People") {
                        
                        if viewModel.followedPeople.isEmpty {
                            
                            Text("You aren't following anyone yet.")
                                .foregroundStyle(.secondary)
                            
                        } else {
                            
                            ForEach(viewModel.followedPeople) { profile in
                                
                                NavigationLink {
                                    AuthorProfileView(userId: profile.id)
                                } label: {
                                    
                                    HStack(spacing: 12) {
                                        
                                        Image(
                                            systemName: "person.crop.circle.fill"
                                        )
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary)
                                        
                                        VStack(
                                            alignment: .leading,
                                            spacing: 4
                                        ) {
                                                
                                            Text(
                                                profile.displayname.isEmpty
                                                ? profile.username
                                                : profile.displayname
                                            )
                                            .fontWeight(.semibold)
                                            
                                            Text("@\(profile.username)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            if !profile.bio.isEmpty {
                                                Text(profile.bio)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    
                    Section("Projects") {
                        
                        if viewModel.followedProjects.isEmpty {
                            
                            Text("You aren't following any Projects yet.")
                                .foregroundStyle(.secondary)
                            
                        } else {
                            
                            ForEach(viewModel.followedProjects) { project in
                            
                                NavigationLink {
                                    ProjectRouteView(
                                        projectId: project.id
                                    )
                                } label: {
                                    
                                    Label(
                                        project.name,
                                        systemImage: "folder"
                                    )
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                    
                    if let error = viewModel.errorMessage {
                        Section {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.loadFollowing()
                }
            }
        }
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await viewModel.reloadVisibleFollowing()
            }
        }
    }
}
