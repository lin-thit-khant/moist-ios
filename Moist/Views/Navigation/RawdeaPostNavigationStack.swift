//
//  RawdeaPostNavigationStack.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//

import SwiftUI

enum RawdeaPostRoute: Hashable {

    case author(UUID)
    case discussion(UUID)
    case project(UUID)
    case savedPosts
    case following
    case followers
    case settings
    case suggestions(UUID)
    case mySuggestions(UUID?)
    case contributors(UUID)
    case invitation(UUID)
}

private struct RawdeaOpenExploreActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct RawdeaCreatePostActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct RawdeaCreatePostInProjectActionKey: EnvironmentKey {
    static let defaultValue: ((Project) -> Void)? = nil
}

extension EnvironmentValues {

    /// Switches to the Explore tab. Set by RawdeaMainTabView.
    var rawdeaOpenExplore: (() -> Void)? {
        get { self[RawdeaOpenExploreActionKey.self] }
        set { self[RawdeaOpenExploreActionKey.self] = newValue }
    }

    /// Opens Compose. Set by RawdeaMainTabView.
    var rawdeaCreatePost: (() -> Void)? {
        get { self[RawdeaCreatePostActionKey.self] }
        set { self[RawdeaCreatePostActionKey.self] = newValue }
    }

    /// Opens Compose with a Project already chosen. Set by RawdeaMainTabView.
    var rawdeaCreatePostInProject: ((Project) -> Void)? {
        get { self[RawdeaCreatePostInProjectActionKey.self] }
        set { self[RawdeaCreatePostInProjectActionKey.self] = newValue }
    }
}

private struct RawdeaPostRouteActionKey:
    EnvironmentKey {

    static let defaultValue:
        ((RawdeaPostRoute) -> Void)? = nil
}

extension EnvironmentValues {

    var rawdeaOpenPostRoute:
        ((RawdeaPostRoute) -> Void)? {

        get {
            self[RawdeaPostRouteActionKey.self]
        }

        set {
            self[RawdeaPostRouteActionKey.self] = newValue
        }
    }
}

struct RawdeaPostNavigationStack<Content: View>: View {

    @State private var path: [RawdeaPostRoute] = []

    private let rootContent: Content
    private let rootRequest: Int

    init(
        rootRequest: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.rootRequest = rootRequest
        self.rootContent = content()
    }

    var body: some View {

        NavigationStack(path: $path) {

            rootContent
                .navigationDestination(
                    for: RawdeaPostRoute.self
                ) { route in

                    switch route {

                    case .author(let userId):

                        AuthorProfileView(
                            userId: userId
                        )

                    case .discussion(let postId):

                        PostDetailView(
                            postId: postId
                        )

                    case .project(let projectId):

                        ProjectRouteView(
                            projectId: projectId
                        )

                    case .savedPosts:

                        SavedPostsView()

                    case .following:

                        FollowingView()

                    case .followers:

                        FollowersView()
                        
                    case .settings:

                        RawdeaSettingsView()

                    case .suggestions(let projectId):

                        SuggestionListView(
                            scope: .review(projectId: projectId)
                        )

                    case .contributors(let projectId):

                        ContributorsView(projectId: projectId)

                    case .invitation(let projectId):

                        ContributorInviteView(projectId: projectId)

                    case .mySuggestions(let projectId):

                        SuggestionListView(
                            scope: .mine(projectId: projectId)
                        )
                    }
                }
        }
        .onChange(of: rootRequest) { _, _ in
            path.removeAll()
        }
        .environment(
            \.rawdeaOpenPostRoute,
            { route in

                guard path.last != route else {
                    return
                }

                path.append(route)
            }
        )
    }
}
