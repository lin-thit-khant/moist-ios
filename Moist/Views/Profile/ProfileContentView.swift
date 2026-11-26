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

    private var displayName: String {

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
            spacing: RawdeaSpacing.md
        ) {

            // At accessibility sizes the avatar moves above the names so the
            // display name and username get the full row width.
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.sm))
                : AnyLayout(HStackLayout(alignment: .center, spacing: RawdeaSpacing.md))

            headerLayout {

                RawdeaInitialAvatar(
                    name: displayName,
                    size: 64,
                    font: .title.weight(.semibold)
                )

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
            }

            if profile.bio.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {

                Text("No bio yet")
                    .font(
                        RawdeaTypography.secondary
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

            } else {

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
}

