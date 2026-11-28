//
//  FollowersView.swift
//  Rawdea
//

import SwiftUI

/// People who follow the signed-in user.
struct FollowersView: View {

    @State private var followers: [PostAuthor]?
    @State private var didFail = false

    var body: some View {

        Group {
            if didFail {
                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load followers",
                    message: "Check your connection and try again.",
                    actionTitle: "Try Again"
                ) {
                    Task { await load() }
                }
            } else if let followers {
                if followers.isEmpty {
                    RawdeaEmptyState(
                        symbol: "person.2",
                        title: "No followers yet",
                        message: "People who follow you appear here."
                    )
                } else {
                    list(followers)
                }
            } else {
                RawdeaLoadingIndicator("Loading followers...")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func list(_ people: [PostAuthor]) -> some View {

        List(people, id: \.id) { person in
            let name = person.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

            NavigationLink(value: RawdeaPostRoute.author(person.id)) {
                HStack(spacing: RawdeaSpacing.sm) {
                    RawdeaInitialAvatar(name: name.isEmpty ? person.username : name)

                    VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                        Text(name.isEmpty ? person.username : name)
                            .font(RawdeaTypography.authorName)
                            .foregroundStyle(RawdeaPalette.primaryText)
                        Text("@\(person.username)")
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                    }
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            }
            .listRowBackground(RawdeaPalette.canvas)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .rawdeaRefreshable { await load() }
    }

    private func load() async {
        didFail = false
        do {
            followers = try await FollowingService().fetchFollowers()
        } catch is CancellationError {
            return
        } catch {
            if followers == nil { didFail = true }
        }
    }
}
