//
//  PublicProfileSectionsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 10/11/2569 BE.
//

import SwiftUI

struct PublicProfileSectionsView: View {

    let userId: UUID

    @StateObject private var postsViewModel =
        AuthorPostsViewModel()

    @StateObject private var projectsViewModel =
        ProjectsViewModel()

    private var freePosts: [Post] {
        postsViewModel.posts.filter {
            $0.projectId == nil && !$0.isHidden
        }
    }

    private var publicProjects: [Project] {
        projectsViewModel.projects
            .filter { !$0.isArchived && !$0.isHidden }
            .sorted { first, second in
                if first.isPinned != second.isPinned {
                    return first.isPinned
                }

                return first.createdAt > second.createdAt
            }
    }

    private func latestPreview(
        for projectId: UUID
    ) -> String? {
        postsViewModel.posts.first {
            $0.projectId == projectId && !$0.isHidden
        }?.content
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 28) {

            // Free posts

            VStack(alignment: .leading, spacing: 12) {

                Text("Free posts")
                    .font(.headline)

                if postsViewModel.isLoading {
                    ProgressView("Loading posts...")

                } else if let error =
                            postsViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                } else if freePosts.isEmpty {
                    Text("No public free posts yet.")
                        .foregroundStyle(.secondary)

                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(freePosts) { post in

                            PostRowView(post: post)

                            Divider()
                        }
                    }
                }
            }

            // Projects

            VStack(alignment: .leading, spacing: 12) {

                Text("Projects")
                    .font(.headline)

                if projectsViewModel.isLoading {
                    ProgressView("Loading Projects...")

                } else if let error =
                            projectsViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                } else if publicProjects.isEmpty {
                    Text("No public Projects yet.")
                        .foregroundStyle(.secondary)

                } else {
                    ForEach(publicProjects) { project in

                        NavigationLink {
                            ProjectRouteView(
                                projectId: project.id
                            )
                        } label: {

                            VStack(
                                alignment: .leading,
                                spacing: 6
                            ) {

                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .fontWeight(.medium)

                                    if project.isPinned {
                                        Image(
                                            systemName: "pin.fill"
                                        )
                                    }
                                }

                                if let preview = latestPreview(
                                    for: project.id
                                ) {
                                    Text(preview)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding()
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(
                                    cornerRadius: 12
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .task(id: userId) {
            await postsViewModel.loadPosts(userId: userId)
            await projectsViewModel.loadProjects(userId: userId)
        }
    }
}
