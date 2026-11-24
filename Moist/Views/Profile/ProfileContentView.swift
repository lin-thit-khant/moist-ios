//
//  ProfileContentView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct ProfileContentView: View {

    let profile: Profile

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

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.md
            ) {

                Image(
                    systemName: "person.crop.circle.fill"
                )
                .resizable()
                .scaledToFit()
                .frame(
                    width: 68,
                    height: 68
                )
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
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

                    Text("@\(profile.username)")
                        .font(
                            RawdeaTypography.secondary
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
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

