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
        let isFollowing = viewModel.isFollowing
        let isDisabled = viewModel.isUpdating || isInteractionBlocked
        let foreground = isFollowing || isInteractionBlocked
            ? RawdeaPalette.primaryText
            : RawdeaPalette.onAccent
        let background = isFollowing || isInteractionBlocked
            ? RawdeaPalette.surface
            : RawdeaPalette.accent
        let shape = RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)

        return Button {
            Task { await viewModel.toggleFollow(userId: userId) }
        } label: {
            HStack(spacing: RawdeaSpacing.xs) {
                if viewModel.isUpdating {
                    ProgressView()
                        .tint(foreground)
                        .accessibilityHidden(true)
                } else if isFollowing {
                    Image(systemName: "checkmark")
                        .accessibilityHidden(true)
                }

                Text(isFollowing ? "Following" : "Follow")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(RawdeaTypography.button)
            .foregroundStyle(foreground)
            .padding(.horizontal, RawdeaSpacing.md)
            .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget)
            .padding(.vertical, RawdeaSpacing.xs)
            .background(background, in: shape)
            .overlay {
                if isFollowing || isInteractionBlocked {
                    shape.strokeBorder(RawdeaPalette.activityOutline)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        // One explicit element: SwiftUI otherwise drops the button role after
        // the label changes from icon + text back to text only.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isFollowing ? "Unfollow account" : "Follow account")
        .accessibilityValue(viewModel.isUpdating ? "Updating" : isFollowing ? "Following" : "Not following")
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
