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
    case settings
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

    init(
        @ViewBuilder content: () -> Content
    ) {
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
                        
                    case .settings:

                        RawdeaSettingsView()
                    }
                }
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
