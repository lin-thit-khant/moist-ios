//
//  FollowingView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 15/11/2569 BE.
//

import SwiftUI

struct FollowingView: View {

    @StateObject private var viewModel =
        FollowingViewModel()

    var body: some View {

        Group {

            if viewModel.isLoading &&
               viewModel.followedPeople.isEmpty &&
               viewModel.followedProjects.isEmpty {

                ProgressView("Loading following...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            } else if let error =
                viewModel.errorMessage,
                viewModel.followedPeople.isEmpty &&
                viewModel.followedProjects.isEmpty {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load following",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {

                        await viewModel.loadFollowing()
                    }
                }

            } else {

                followingList
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            Task {

                await viewModel
                    .reloadVisibleFollowing()
            }
        }
    }

    private var followingList: some View {

        List {

            Section("People") {

                if viewModel.followedPeople.isEmpty {

                    Text("You aren't following anyone yet.")
                        .font(
                            RawdeaTypography.secondary
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )

                } else {

                    ForEach(
                        viewModel.followedPeople
                    ) { profile in

                        NavigationLink(
                            value: RawdeaPostRoute.author(
                                profile.id
                            )
                        ) {

                            HStack(
                                alignment: .top,
                                spacing: RawdeaSpacing.sm
                            ) {

                                Image(
                                    systemName:
                                        "person.crop.circle.fill"
                                )
                                .font(.system(.title2))
                                .foregroundStyle(
                                    RawdeaPalette.secondaryText
                                )
                                .accessibilityHidden(true)

                                VStack(
                                    alignment: .leading,
                                    spacing: RawdeaSpacing.xxs
                                ) {

                                    Text(
                                        profile.displayname.isEmpty
                                        ? profile.username
                                        : profile.displayname
                                    )
                                    .font(
                                        RawdeaTypography.authorName
                                    )
                                    .foregroundStyle(
                                        RawdeaPalette.primaryText
                                    )

                                    Text("@\(profile.username)")
                                        .font(
                                            RawdeaTypography.metadata
                                        )
                                        .foregroundStyle(
                                            RawdeaPalette.secondaryText
                                        )

                                    if !profile.bio.isEmpty {

                                        Text(profile.bio)
                                            .font(
                                                RawdeaTypography.secondary
                                            )
                                            .foregroundStyle(
                                                RawdeaPalette.secondaryText
                                            )
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(
                                .vertical,
                                RawdeaSpacing.xs
                            )
                        }
                        .listRowBackground(
                            RawdeaPalette.canvas
                        )
                    }
                }
            }

            Section("Projects") {

                if viewModel.followedProjects.isEmpty {

                    Text("You aren't following any Projects yet.")
                        .font(
                            RawdeaTypography.secondary
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )

                } else {

                    ForEach(
                        viewModel.followedProjects
                    ) { project in

                        NavigationLink(
                            value: RawdeaPostRoute.project(
                                project.id
                            )
                        ) {

                            RawdeaProjectCard(
                                project: project
                            )
                            .padding(
                                .vertical,
                                RawdeaSpacing.xs
                            )
                        }
                        .listRowBackground(
                            RawdeaPalette.canvas
                        )
                    }
                }
            }

            if let error = viewModel.errorMessage {

                Section {

                    RawdeaInlineError(
                        message: error
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas)
        .refreshable {

            await viewModel.loadFollowing()
        }
    }
}
