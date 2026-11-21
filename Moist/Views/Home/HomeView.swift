//
//  HomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//


import SwiftUI
import Supabase

// MARK: - Home feed selection

enum RawdeaHomeFeed: String, CaseIterable {

    case all
    case following

    var title: String {

        switch self {

        case .all:
            return "All Posts"

        case .following:
            return "Following"
        }
    }
}

// MARK: - Home destination

struct HomeView: View {

    @ObservedObject var feedViewModel: FeedViewModel

    @Binding var selectedFeed: RawdeaHomeFeed

    @Binding var recentlyCreatedPost: Post?

    @StateObject private var followingFeedViewModel =
        FollowingFeedViewModel()

    @State private var currentUserId: UUID?

    @Environment(\.scenePhase)
    private var scenePhase

    var body: some View {

        VStack(spacing: 0) {

            // MARK: - Underlined selector

            feedSelector

            // MARK: - Feed content

            Group {

                switch selectedFeed {

                case .all:

                    allPostsContent

                case .following:

                    FollowingFeedView(
                        viewModel: followingFeedViewModel
                    )
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                }
            }
        }
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )

        // Approved text-only compact header.
        .navigationTitle("Rawdea")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Current user

        .task {

            do {

                let user = try await SupabaseManager
                    .client
                    .auth
                    .session
                    .user

                currentUserId = user.id

            } catch {

                currentUserId = nil

                print(
                    "Couldn't retrieve current user: \(error)"
                )
            }
        }

        // MARK: - Foreground revalidation

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {

                switch selectedFeed {

                case .all:

                    await feedViewModel
                        .reloadVisiblePosts()

                case .following:

                    await followingFeedViewModel
                        .reloadVisiblePosts()
                }
            }
        }
    }

    // MARK: - Feed selector

    private var feedSelector: some View {

        HStack(alignment: .bottom, spacing: 0) {

            ForEach(RawdeaHomeFeed.allCases, id: \.self) {
                feed in

                feedTabButton(feed)
            }
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.top, RawdeaSpacing.xs)
        .background(RawdeaPalette.canvas)
        .overlay(alignment: .bottom) {

            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
    }

    private func feedTabButton(
        _ feed: RawdeaHomeFeed
    ) -> some View {

        let isSelected = selectedFeed == feed

        return Button {

            guard selectedFeed != feed else {
                return
            }

            selectedFeed = feed

        } label: {

            VStack(spacing: RawdeaSpacing.xs) {

                Text(feed.title)
                    .font(
                        RawdeaTypography.authorName
                    )
                    .foregroundStyle(
                        isSelected
                        ? RawdeaPalette.primaryText
                        : RawdeaPalette.secondaryText
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: RawdeaSpacing.minimumTouchTarget
                    )

                Rectangle()
                    .fill(
                        isSelected
                        ? RawdeaPalette.accent
                        : Color.clear
                    )
                    .frame(height: 2)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.title)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
    }

    // MARK: - All Posts

    private var allPostsContent: some View {

        VStack(spacing: 0) {

            if let post = recentlyCreatedPost {

                publishedPostConfirmation(post)
            }

            FeedView(
                viewModel: feedViewModel,
                currentUserId: currentUserId
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )

            // Preserve the existing behavior:
            // remove the temporary publication
            // banner if the visible feed no
            // longer contains the published post.
            .onChange(
                of: feedViewModel.posts.map(\.id)
            ) { _, postIds in

                guard let recentlyCreatedPost else {
                    return
                }

                if !postIds.contains(
                    recentlyCreatedPost.id
                ) {

                    self.recentlyCreatedPost = nil
                }
            }
        }
    }

    // MARK: - Publication confirmation

    private func publishedPostConfirmation(
        _ post: Post
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: RawdeaSpacing.sm
        ) {

            Image(systemName: "checkmark.circle")
                .foregroundStyle(
                    RawdeaPalette.accent
                )
                .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.xxs
            ) {

                Text("Your post was published")
                    .font(
                        RawdeaTypography.authorName
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )

                Text(
                    feedViewModel.posts.first(
                        where: { $0.id == post.id }
                    )?.content ?? post.content
                )
                .font(RawdeaTypography.metadata)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(RawdeaSpacing.sm)
        .background(
            RawdeaPalette.surface,
            in: RoundedRectangle(
                cornerRadius: RawdeaSpacing.buttonRadius
            )
        )
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .padding(.vertical, RawdeaSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
