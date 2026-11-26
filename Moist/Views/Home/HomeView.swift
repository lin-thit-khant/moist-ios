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

    @Binding var publishedPostID: UUID?

    let pendingPublishedPostID: UUID?
    let onCreatePost: () -> Void
    let onExplore: () -> Void

    @StateObject private var followingFeedViewModel =
        FollowingFeedViewModel()

    @State private var currentUserId: UUID?

    @Environment(\.scenePhase)
    private var scenePhase

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    @Environment(\.rawdeaOpenPostRoute)
    private var openPostRoute

    @Environment(\.accessibilityVoiceOverEnabled)
    private var voiceOverEnabled

    @AccessibilityFocusState(for: .voiceOver)
    private var isPublicationActionFocused: Bool

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
                        viewModel: followingFeedViewModel,
                        onExplore: onExplore
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
        .overlay(alignment: .bottom) {
            if selectedFeed == .all, let publishedPostID {
                publicationConfirmation(postID: publishedPostID)
                    .padding(.horizontal, RawdeaSpacing.screenInset)
                    .padding(.bottom, RawdeaSpacing.xs)
            }
        }
        .task(id: publishedPostID) {
            guard let publishedPostID else { return }
            AccessibilityNotification.Announcement("Post published").post()

            do {
                try await Task.sleep(for: .seconds(voiceOverEnabled ? 10 : 5))
                while isPublicationActionFocused {
                    try await Task.sleep(for: .seconds(1))
                }
                if self.publishedPostID == publishedPostID {
                    self.publishedPostID = nil
                }
            } catch {
                return
            }
        }
        .onChange(of: selectedFeed) { _, feed in
            if feed != .all {
                publishedPostID = nil
            }
        }
        .onDisappear {
            publishedPostID = nil
        }

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

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 0))

        return layout {

            ForEach(RawdeaHomeFeed.allCases, id: \.self) {
                feed in

                feedTabButton(feed)
            }
        }
        .padding(.horizontal, RawdeaSpacing.screenInset)
        .background(alignment: .bottom) {

            Rectangle()
                .fill(RawdeaPalette.divider)
                .frame(height: 0.5)
                .accessibilityHidden(true)
        }
        .background(RawdeaPalette.canvas)
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

            Text(feed.title)
                .font(RawdeaTypography.authorName)
                .foregroundStyle(
                    isSelected
                    ? RawdeaPalette.primaryText
                    : RawdeaPalette.secondaryText
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, RawdeaSpacing.xxs)
                .frame(
                    maxWidth: .infinity,
                    minHeight: RawdeaSpacing.minimumTouchTarget
                )
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Rectangle()
                            .fill(RawdeaPalette.accent)
                            .frame(height: 2)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.title)
        .accessibilityAddTraits(
            isSelected ? .isSelected : []
        )
        .accessibilityIdentifier("home-feed-\(feed.rawValue)")
    }

    // MARK: - All Posts

    private var allPostsContent: some View {
        FeedView(
            viewModel: feedViewModel,
            currentUserId: currentUserId,
            newlyPublishedPostID: pendingPublishedPostID ?? publishedPostID,
            onCreatePost: onCreatePost
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Publication confirmation

    private func publicationConfirmation(postID: UUID) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.sm))

        return layout {
            Label("Post published", systemImage: "checkmark.circle.fill")
                .font(RawdeaTypography.authorName)
                .foregroundStyle(RawdeaPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let openPostRoute,
               feedViewModel.posts.contains(where: { $0.id == postID }) {
                Button {
                    publishedPostID = nil
                    openPostRoute(.discussion(postID))
                } label: {
                    Text("View")
                        .font(RawdeaTypography.authorName)
                        .frame(
                            minWidth: RawdeaSpacing.minimumTouchTarget,
                            minHeight: RawdeaSpacing.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(RawdeaPalette.accent)
                .accessibilityLabel("View published post")
                .accessibilityFocused($isPublicationActionFocused)
            }
        }
        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
        .padding(.horizontal, RawdeaSpacing.sm)
        .padding(.vertical, RawdeaSpacing.xxs)
        .background(RawdeaPalette.surface, in: RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius))
        .overlay {
            RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                .strokeBorder(RawdeaPalette.activityOutline)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
    }
}
