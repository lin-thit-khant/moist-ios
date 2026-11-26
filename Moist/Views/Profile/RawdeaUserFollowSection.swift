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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

                counts

                if !viewModel.isOwnProfile {
                    followButton
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

    private var counts: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: RawdeaSpacing.xl))
        let followers = viewModel.followerCount
        let following = viewModel.followingCount

        return layout {
            statistic(
                value: followers,
                title: followers == 1 ? "Follower" : "Followers",
                accessibilityLabel: followers == 1 ? "1 follower" : "\(followers.formatted()) followers"
            )
            statistic(
                value: following,
                title: "Following",
                accessibilityLabel: following == 1 ? "Following 1 person" : "Following \(following.formatted()) people"
            )
        }
    }

    private var followButton: some View {
        RawdeaFollowButton(
            isFollowing: viewModel.isFollowing,
            isUpdating: viewModel.isUpdating,
            isBlocked: isInteractionBlocked,
            followLabel: "Follow account",
            unfollowLabel: "Unfollow account"
        ) {
            Task { await viewModel.toggleFollow(userId: userId) }
        }
        .accessibilityIdentifier("profile-follow-action")
    }

    private func statistic(
        value: Int,
        title: String,
        accessibilityLabel: String
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
            accessibilityLabel
        )
    }
}
