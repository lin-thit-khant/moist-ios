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
            $0.projectId == nil &&
            !$0.isHidden
        }
    }

    private var publicProjects: [Project] {

        projectsViewModel.projects
            .filter {
                !$0.isArchived &&
                !$0.isHidden
            }
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
            $0.projectId == projectId &&
            !$0.isHidden
        }?.content
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xl
        ) {

            freePostsSection

            projectsSection
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .task(id: userId) {

            await postsViewModel.loadPosts(
                userId: userId
            )

            await projectsViewModel.loadProjects(
                userId: userId
            )
        }
    }

    // MARK: - Free posts

    private var freePostsSection: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.md
        ) {

            sectionTitle("Free posts")

            if postsViewModel.isLoading &&
               postsViewModel.posts.isEmpty {

                ProgressView("Loading posts...")

            } else if let error =
                postsViewModel.errorMessage,
                postsViewModel.posts.isEmpty {

                RawdeaInlineError(
                    message: error
                )

                Button("Try Again") {

                    Task {

                        await postsViewModel.loadPosts(
                            userId: userId
                        )
                    }
                }
                .frame(
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget
                )

            } else if freePosts.isEmpty {

                Text("No public free posts yet.")
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

            } else {

                LazyVStack(spacing: 0) {

                    ForEach(freePosts) { post in

                        PostRowView(post: post)

                        Divider()
                            .overlay(
                                RawdeaPalette.divider
                            )
                    }
                }
            }

            if !postsViewModel.posts.isEmpty,
               let error = postsViewModel.errorMessage {

                RawdeaInlineError(
                    message:
                        "Couldn't refresh posts. \(error)"
                )
            }
        }
    }

    // MARK: - Public Projects

    private var projectsSection: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.md
        ) {

            sectionTitle("Projects")

            if projectsViewModel.isLoading &&
               projectsViewModel.projects.isEmpty {

                ProgressView("Loading Projects...")

            } else if let error =
                projectsViewModel.errorMessage,
                projectsViewModel.projects.isEmpty {

                RawdeaInlineError(
                    message: error
                )

                Button("Try Again") {

                    Task {

                        await projectsViewModel.loadProjects(
                            userId: userId
                        )
                    }
                }
                .frame(
                    minHeight:
                        RawdeaSpacing.minimumTouchTarget
                )

            } else if publicProjects.isEmpty {

                Text("No public Projects yet.")
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

            } else {

                ForEach(publicProjects) { project in

                    NavigationLink(
                        value: RawdeaPostRoute.project(
                            project.id
                        )
                    ) {

                        RawdeaProjectSurface {

                            RawdeaProjectCard(
                                project: project,
                                preview: latestPreview(
                                    for: project.id
                                )
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(
                        "Opens Project"
                    )
                }
            }

            if !projectsViewModel.projects.isEmpty,
               let error = projectsViewModel.errorMessage {

                RawdeaInlineError(
                    message:
                        "Couldn't refresh Projects. \(error)"
                )
            }
        }
    }

    private func sectionTitle(
        _ title: String
    ) -> some View {

        Text(title)
            .font(RawdeaTypography.sectionTitle)
            .foregroundStyle(
                RawdeaPalette.primaryText
            )
            .accessibilityAddTraits(.isHeader)
    }
}
