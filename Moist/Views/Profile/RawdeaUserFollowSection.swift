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

                RawdeaLoadingIndicator("Loading follows...")
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
        let followers = viewModel.followerCount
        let following = viewModel.followingCount

        return Text("\(Text(followers.formatted()).fontWeight(.semibold).foregroundStyle(RawdeaPalette.primaryText)) \(followers == 1 ? "follower" : "followers") · \(Text(following.formatted()).fontWeight(.semibold).foregroundStyle(RawdeaPalette.primaryText)) following")
            .font(RawdeaTypography.secondary)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var followButton: some View {
        RawdeaFollowButton(
            isFollowing: viewModel.isFollowing,
            isUpdating: viewModel.isUpdating,
            isBlocked: isInteractionBlocked,
            isWide: true,
            followLabel: "Follow account",
            unfollowLabel: "Unfollow account"
        ) {
            Task { await viewModel.toggleFollow(userId: userId) }
        }
        .accessibilityIdentifier("profile-follow-action")
    }
}
