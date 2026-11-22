//
//  RawdeaPostNavigationStack.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 22/11/2569 BE.
//



import SwiftUI

// MARK: - Navigation destinations

enum RawdeaPostRoute: Hashable {

    case author(UUID)
    case discussion(UUID)
    case project(UUID)

    // Saved Posts now participates in the
    // same navigation path as post routes.
    case savedPosts
}

// MARK: - Navigation environment

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

// MARK: - Navigation stack

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
                    }
                }
        }
        .environment(
            \.rawdeaOpenPostRoute,
            { route in

                path.append(route)
            }
        )
    }
}
