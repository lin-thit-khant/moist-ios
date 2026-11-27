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

    private var publicPosts: [Post] {

        postsViewModel.posts.filter { !$0.isHidden }
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

    @State private var hasLoaded = false

    /// Both lists loaded without errors and nothing is public.
    private var hasNothingPublic: Bool {
        hasLoaded &&
        postsViewModel.errorMessage == nil &&
        projectsViewModel.errorMessage == nil &&
        publicPosts.isEmpty &&
        publicProjects.isEmpty
    }

    var body: some View {

        Group {
            if hasNothingPublic {
                // One message instead of an empty Posts tab and an empty Projects tab.
                RawdeaEmptyState(
                    symbol: "doc.text",
                    title: "Nothing shared yet",
                    message: "Public posts and Projects will appear here."
                )
            } else {
                RawdeaProfileWorkSections(
                    pinnedProjects: publicProjects.filter(\.isPinned),
                    projectRow: projectRow,
                    posts: { postsSection },
                    projects: { projectsSection }
                )
            }
        }
        .task(id: userId) {

            hasLoaded = false

            await postsViewModel.loadPosts(
                userId: userId
            )

            await projectsViewModel.loadProjects(
                userId: userId
            )

            hasLoaded = true
        }
    }

    // MARK: - Posts

    private var postsSection: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.md
        ) {

            if postsViewModel.isLoading &&
               postsViewModel.posts.isEmpty {

                RawdeaLoadingIndicator("Loading posts...")

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

            } else if publicPosts.isEmpty {

                Text("No public posts yet.")
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

            } else {

                LazyVStack(spacing: 0) {

                    ForEach(publicPosts) { post in

                        PostRowView(post: post, horizontalInset: 0)

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

            if projectsViewModel.isLoading &&
               projectsViewModel.projects.isEmpty {

                RawdeaLoadingIndicator("Loading Projects...")

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

                ForEach(publicProjects.filter { !$0.isPinned }, content: projectRow)
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

    private func projectRow(_ project: Project) -> some View {
        NavigationLink(value: RawdeaPostRoute.project(project.id)) {
            RawdeaProjectSurface {
                RawdeaProjectCard(
                    project: project,
                    preview: latestPreview(for: project.id)
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Project")
    }
}
