//
//  ProfileContentView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct ProfileContentView: View {

    let profile: Profile

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var displayName: String {
        Self.displayName(for: profile)
    }

    static func displayName(for profile: Profile) -> String {

        let name = profile.displayname
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        return name.isEmpty
            ? profile.username
            : name
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.sm
        ) {

            // At accessibility sizes the avatar moves above the names so the
            // display name and username get the full row width.
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.sm))
                : AnyLayout(HStackLayout(alignment: .center, spacing: RawdeaSpacing.md))

            headerLayout {

                if dynamicTypeSize.isAccessibilitySize {
                    avatar
                }

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xxs
                ) {

                    Text(displayName)
                        .font(
                            RawdeaTypography.screenTitle
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .accessibilityAddTraits(
                            .isHeader
                        )

                    // A username is one unbroken token, so wrapping splits it
                    // mid-word. Keep it on one line; VoiceOver still reads it in full.
                    Text("@\(profile.username)")
                        .font(
                            RawdeaTypography.secondary
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.8)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                if !dynamicTypeSize.isAccessibilitySize {
                    avatar
                }
            }

            if !profile.bio.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {

                Text(profile.bio)
                    .font(
                        RawdeaTypography.postBody
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    private var avatar: some View {
        RawdeaInitialAvatar(
            name: displayName,
            size: 64,
            font: .title.weight(.semibold)
        )
    }
}

// MARK: - Share

/// Rawdea has no public web addresses yet, so this shares the handle.
struct RawdeaShareProfileLink: View {

    let profile: Profile

    var body: some View {
        ShareLink(
            item: "\(ProfileContentView.displayName(for: profile)) (@\(profile.username)) on Rawdea"
        ) {
            RawdeaOutlinePillLabel(title: "Share profile")
        }
        .buttonStyle(.plain)
    }
}
