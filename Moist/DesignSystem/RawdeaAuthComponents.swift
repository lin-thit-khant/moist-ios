//
//  RawdeaAuthComponents.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//

import SwiftUI
import UIKit

// MARK: - Rawdea brand

struct RawdeaAuthBrand: View {

    var body: some View {

        VStack(spacing: RawdeaSpacing.md) {

            // Use the original Cell Study artwork
            // when the asset has been installed.

            if let logo = UIImage(
                named: "RawdeaLogo"
            ) {

                Image(uiImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: 104,
                        maxHeight: 104
                    )
                    .accessibilityHidden(true)
            }

            Text("Rawdea")
                .font(
                    .system(
                        .largeTitle,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityAddTraits(.isHeader)

            Text(
                "A quiet space for unfinished ideas."
            )
            .font(RawdeaTypography.body)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .multilineTextAlignment(.center)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Authentication heading

struct RawdeaAuthHeading: View {

    let title: String
    let message: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text(title)
                .font(
                    .system(
                        .title,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(RawdeaTypography.secondary)
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
}

// MARK: - Shared field surface

private struct RawdeaAuthFieldSurface:
    ViewModifier {

    func body(
        content: Content
    ) -> some View {

        content
            .font(RawdeaTypography.body)
            .foregroundStyle(
                RawdeaPalette.primaryText
            )
            .padding(
                .horizontal,
                RawdeaSpacing.sm
            )
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .background(
                RawdeaPalette.surface,
                in: RoundedRectangle(
                    cornerRadius:
                        RawdeaSpacing.buttonRadius
                )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        RawdeaSpacing.buttonRadius
                )
                .strokeBorder(
                    RawdeaPalette.activityOutline,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
            }
    }
}

// MARK: - Email input

struct RawdeaEmailField: View {

    @Binding var email: String

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text("Email address")
                .font(RawdeaTypography.authorName)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityHidden(true)

            TextField(
                "you@example.com",
                text: $email
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .modifier(
                RawdeaAuthFieldSurface()
            )
            .accessibilityLabel("Email address")
        }
    }
}

// MARK: - Password input

struct RawdeaPasswordField: View {

    let title: String

    @Binding var password: String

    var isNewPassword = false

    @State private var isVisible = false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            Text(title)
                .font(RawdeaTypography.authorName)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityHidden(true)

            HStack(
                spacing: RawdeaSpacing.xs
            ) {

                Group {

                    if isVisible {

                        TextField(
                            title,
                            text: $password
                        )

                    } else {

                        SecureField(
                            title,
                            text: $password
                        )
                    }
                }
                .textContentType(
                    isNewPassword
                    ? .newPassword
                    : .password
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(title)

                Button {

                    isVisible.toggle()

                } label: {

                    Image(
                        systemName:
                            isVisible
                            ? "eye.slash"
                            : "eye"
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .frame(
                        width:
                            RawdeaSpacing.minimumTouchTarget,
                        height:
                            RawdeaSpacing.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isVisible
                    ? "Hide \(title.lowercased())"
                    : "Show \(title.lowercased())"
                )
            }
            .modifier(
                RawdeaAuthFieldSurface()
            )
        }

        // Avoid leaving a visible password
        // exposed when returning to this screen.

        .onDisappear {
            isVisible = false
        }
    }
}

// MARK: - Authentication status

struct RawdeaAuthStatus: View {

    let message: String

    var body: some View {

        HStack(
            alignment: .top,
            spacing: RawdeaSpacing.sm
        ) {

            Image(
                systemName: "checkmark.circle"
            )
            .foregroundStyle(
                RawdeaPalette.primaryText
            )
            .accessibilityHidden(true)

            Text(message)
                .font(RawdeaTypography.secondary)
                .foregroundStyle(
                    RawdeaPalette.primaryText
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
        .padding(RawdeaSpacing.sm)
        .background(
            RawdeaPalette.surface,
            in: RoundedRectangle(
                cornerRadius:
                    RawdeaSpacing.buttonRadius
            )
        )
        .accessibilityElement(
            children: .combine
        )
    }
}

