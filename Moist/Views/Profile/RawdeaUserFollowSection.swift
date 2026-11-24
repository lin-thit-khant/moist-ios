//
//  RawdeaUserFollowSection.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//


import SwiftUI

struct RawdeaUserFollowSection: View {

    let userId: UUID

    @ObservedObject var viewModel:
        UserFollowViewModel

    let isInteractionBlocked: Bool

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.md
        ) {

            if viewModel.isLoading &&
               !viewModel.hasLoaded {

                ProgressView("Loading follows...")
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )

            } else if viewModel.hasLoaded {

                HStack(spacing: RawdeaSpacing.xl) {

                    statistic(
                        value: viewModel.followerCount,
                        title: "Followers"
                    )

                    statistic(
                        value: viewModel.followingCount,
                        title: "Following"
                    )

                    Spacer(minLength: 0)
                }

                if !viewModel.isOwnProfile {

                    RawdeaPrimaryButton(
                        viewModel.isFollowing
                        ? "Following"
                        : "Follow",
                        isLoading:
                            viewModel.isUpdating,
                        isEnabled:
                            !viewModel.isUpdating &&
                            !isInteractionBlocked
                    ) {

                        Task {

                            await viewModel.toggleFollow(
                                userId: userId
                            )
                        }
                    }
                    .accessibilityLabel(
                        viewModel.isFollowing
                        ? "Unfollow account"
                        : "Follow account"
                    )
                }
            }

            if let error = viewModel.errorMessage {

                RawdeaInlineError(
                    message: error
                )

                if !viewModel.hasLoaded {

                    Button("Retry Follow Status") {

                        Task {

                            await viewModel.load(
                                userId: userId
                            )
                        }
                    }
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private func statistic(
        value: Int,
        title: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xxs
        ) {

            Text(value.formatted())
                .font(
                    RawdeaTypography.sectionTitle
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )

            Text(title)
                .font(RawdeaTypography.metadata)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
        }
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "\(value) \(title)"
        )
    }
}
