//
//  RawdeaMainTabView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//

import SwiftUI

// MARK: - Main destinations

private enum RawdeaTab: Hashable {

    case home
    case explore
    case create
    case activity
    case profile
}

// MARK: - Signed-in app navigation

struct RawdeaMainTabView: View {

    @ObservedObject var authViewModel: AuthViewModel

    // Shared feed state.
    // Home and successful Compose publication use
    // the same existing feed view model.
    @StateObject private var feedViewModel =
        FeedViewModel()

    // Shared notification state.
    // The Activity screen and its badge use
    // the same existing notification view model.
    @StateObject private var notificationsViewModel =
        NotificationsViewModel()

    // The actual selected destination.
    // .create is never stored as the selection.
    @State private var selectedTab: RawdeaTab = .home

    // Home feed state survives tab changes.
    @State private var selectedHomeFeed:
        RawdeaHomeFeed = .all

    @State private var pendingPublishedPostID: UUID?
    @State private var publishedPostID: UUID?

    @State private var isShowingCompose = false

    @Environment(\.scenePhase)
    private var scenePhase

    // MARK: - Selection interception

    private var tabSelection: Binding<RawdeaTab> {

        Binding(
            get: {
                selectedTab
            },
            set: { requestedTab in

                if requestedTab == .create {

                    guard !isShowingCompose else {
                        return
                    }

                    isShowingCompose = true
                    return
                }

                selectedTab = requestedTab
            }
        )
    }

    // MARK: - Body

    var body: some View {

        TabView(selection: tabSelection) {

            // HOME

            RawdeaPostNavigationStack {

                HomeView(
                    feedViewModel: feedViewModel,
                    selectedFeed: $selectedHomeFeed,
                    publishedPostID: $publishedPostID,
                    pendingPublishedPostID: pendingPublishedPostID,
                    onCreatePost: { isShowingCompose = true },
                    onExplore: { selectedTab = .explore }
                )
            }
            .tabItem {
                Label(
                    "Home",
                    systemImage:
                        selectedTab == .home
                        ? "house.fill"
                        : "house"
                )
            }
            .tag(RawdeaTab.home)

            // EXPLORE

            RawdeaPostNavigationStack {

                DiscoveryView()
            }
            .tabItem {
                Label(
                    "Explore",
                    systemImage:
                        selectedTab == .explore
                        ? "magnifyingglass"
                        : "magnifyingglass"
                )
            }
            .tag(RawdeaTab.explore)

            // CREATE ACTION
            //
            // This is a placeholder destination.
            // The selection binding intercepts taps
            // and opens Compose instead.
            //
            // It must not become selected.

            Color.clear
                .tabItem {
                    Label(
                        "Create",
                        systemImage: "plus"
                    )
                }
                .tag(RawdeaTab.create)

            // ACTIVITY

            RawdeaPostNavigationStack {

                NotificationsView(
                    viewModel: notificationsViewModel
                )
            }
            .tabItem {
                Label(
                    "Activity",
                    systemImage:
                        selectedTab == .activity
                        ? "bell.fill"
                        : "bell"
                )
            }
            .tag(RawdeaTab.activity)
            .badge(notificationsViewModel.unreadCount)
            
            // PROFILE

            RawdeaPostNavigationStack {

                ProfileView(
                    isSelected: selectedTab == .profile
                )
            }
            .tabItem {
                Label(
                    "Profile",
                    systemImage:
                        selectedTab == .profile
                        ? "person.crop.circle.fill"
                        : "person.crop.circle"
                )
            }
            .tag(RawdeaTab.profile)

        }
        .environmentObject(authViewModel)
        // Native five-tab styling.
        // There is no raised Create button.
        .tint(RawdeaPalette.accent)

        // MARK: - Compose presentation

        .sheet(isPresented: $isShowingCompose, onDismiss: showPublicationConfirmation) {

            CreatePostView { publishedPost in

                // The existing CreatePostView calls
                // this callback only after its
                // publication request succeeds.

                handlePublishedPost(publishedPost)
            }
        }

        // MARK: - Badge refresh

        .task {
            await notificationsViewModel
                .refreshUnreadCount()
        }

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {
                await notificationsViewModel
                    .refreshUnreadCount()
            }
        }

        // Refresh the badge whenever Activity
        // has been visited and we return to a
        // different tab.
        .onChange(of: selectedTab) { oldTab, newTab in

            guard oldTab == .activity,
                  newTab != .activity else {
                return
            }

            Task {
                await notificationsViewModel
                    .refreshUnreadCount()
            }
        }
    }

    // MARK: - Successful publication

    private func handlePublishedPost(_ post: Post) {

        // Preserve the old behavior of inserting
        // the published post immediately.
        feedViewModel.addPost(post)

        pendingPublishedPostID = post.id

        // Required by Specification v1.1:
        // return to Home → All Posts.
        selectedHomeFeed = .all
        selectedTab = .home
    }

    private func showPublicationConfirmation() {
        guard let pendingPublishedPostID else { return }
        publishedPostID = pendingPublishedPostID
        self.pendingPublishedPostID = nil
    }
}

