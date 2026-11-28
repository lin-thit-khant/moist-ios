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

    @State private var hasLoaded = false
    @State private var mayHaveReplies = true

    /// Both lists loaded without errors and nothing is public.
    private var hasNothingPublic: Bool {
        hasLoaded &&
        postsViewModel.errorMessage == nil &&
        projectsViewModel.errorMessage == nil &&
        publicPosts.isEmpty &&
        publicProjects.isEmpty &&
        !mayHaveReplies
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
                    userId: userId,
                    chips: { projectChips },
                    posts: { postsSection }
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

            // A failed check keeps the tabs, where it can be retried.
            let replies = try? await PostEngagementService()
                .fetchReplies(userId: userId)
            mayHaveReplies = replies?.isEmpty != true

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

    @ViewBuilder
    private var projectChips: some View {

        if let error = projectsViewModel.errorMessage {
            RawdeaInlineError(message: error)
        } else if publicProjects.isEmpty && hasLoaded {
            Text("No public Projects yet.")
                .font(RawdeaTypography.secondary)
                .foregroundStyle(RawdeaPalette.secondaryText)
        }

        ForEach(publicProjects, content: RawdeaProjectChip.init)
    }
}
