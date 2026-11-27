//
//  RawdeaMainTabView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//

import SwiftUI

// MARK: - Main destinations

enum RawdeaTab: Hashable {

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

    // One value per Compose presentation, so the
    // sheet always opens with the chosen Project.
    @State private var composeRequest: ComposeRequest?

    @Environment(\.scenePhase)
    private var scenePhase

    @State private var isKeyboardVisible = false

    // MARK: - Selection interception

    private var tabSelection: Binding<RawdeaTab> {

        Binding(
            get: {
                selectedTab
            },
            set: { requestedTab in

                if requestedTab == .create {

                    guard composeRequest == nil else {
                        return
                    }

                    composeRequest = ComposeRequest(project: nil)
                    return
                }

                selectedTab = requestedTab
            }
        )
    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 0) {

        TabView(selection: tabSelection) {

            // HOME

            RawdeaPostNavigationStack {

                HomeView(
                    feedViewModel: feedViewModel,
                    selectedFeed: $selectedHomeFeed,
                    publishedPostID: $publishedPostID,
                    pendingPublishedPostID: pendingPublishedPostID,
                    onCreatePost: {
                        composeRequest = ComposeRequest(project: nil)
                    },
                    onExplore: { selectedTab = .explore }
                )
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(RawdeaTab.home)

            // EXPLORE

            RawdeaPostNavigationStack {

                DiscoveryView()
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(RawdeaTab.explore)

            // CREATE ACTION
            //
            // This is a placeholder destination.
            // The selection binding intercepts taps
            // and opens Compose instead.
            //
            // It must not become selected.

            Color.clear
                .toolbar(.hidden, for: .tabBar)
                .tag(RawdeaTab.create)

            // ACTIVITY

            RawdeaPostNavigationStack {

                NotificationsView(
                    viewModel: notificationsViewModel
                )
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(RawdeaTab.activity)
            
            // PROFILE

            RawdeaPostNavigationStack {

                ProfileView(
                    isSelected: selectedTab == .profile
                )
            }
            .toolbar(.hidden, for: .tabBar)
            .tag(RawdeaTab.profile)

        }

            // The keyboard takes the bar's place while typing.
            if !isKeyboardVisible {
                RawdeaTabBar(
                    selection: tabSelection,
                    selected: selectedTab,
                    unreadCount: notificationsViewModel.unreadCount
                )
            }
        }
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )) { _ in
            isKeyboardVisible = false
        }
        .environmentObject(authViewModel)
        .environment(\.rawdeaOpenExplore, { selectedTab = .explore })
        .environment(\.rawdeaCreatePost, { composeRequest = ComposeRequest(project: nil) })
        .environment(\.rawdeaCreatePostInProject, { project in
            composeRequest = ComposeRequest(project: project)
        })
        .tint(RawdeaPalette.primaryText)

        // MARK: - Compose presentation

        .sheet(item: $composeRequest, onDismiss: showPublicationConfirmation) { request in

            CreatePostView(initialProject: request.project) { publishedPost in

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

private struct ComposeRequest: Identifiable {
    let id = UUID()
    let project: Project?
}
