//
//  RawdeaComponents.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI

struct RawdeaInitialAvatar: View {
    let name: String
    var size: CGFloat = RawdeaSpacing.xl
    var font: Font = RawdeaTypography.authorName

    var body: some View {
        Text(String(name.first(where: \.isLetter) ?? "?").uppercased())
            .font(font)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(RawdeaPalette.primaryText)
            .frame(width: size, height: size)
            .background(RawdeaPalette.surface, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Follow Button

/// Shared Follow / Following control for people and Projects.
struct RawdeaFollowButton: View {
    let isFollowing: Bool
    let isUpdating: Bool
    var isBlocked: Bool = false
    let followLabel: String
    let unfollowLabel: String
    let action: () -> Void

    var body: some View {
        let isMuted = isFollowing || isBlocked
        let foreground = isMuted ? RawdeaPalette.primaryText : RawdeaPalette.onAccent
        let background = isMuted ? RawdeaPalette.surface : RawdeaPalette.accent
        let shape = RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)

        Button(action: action) {
            HStack(spacing: RawdeaSpacing.xs) {
                if isUpdating {
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
                if isMuted {
                    shape.strokeBorder(RawdeaPalette.activityOutline)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isUpdating || isBlocked)
        // One explicit element: SwiftUI otherwise drops the button role after
        // the label changes from icon + text back to text only.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isFollowing ? unfollowLabel : followLabel)
        .accessibilityValue(isUpdating ? "Updating" : isFollowing ? "Following" : "Not following")
    }
}

// MARK: - Primary Button

struct RawdeaPrimaryButton: View {

    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {

        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    private var usesAccent: Bool {

        isEnabled || isLoading
    }

    private var foregroundColor: Color {

        usesAccent
        ? RawdeaPalette.onAccent
        : RawdeaPalette.secondaryText
    }

    private var backgroundColor: Color {

        usesAccent
        ? RawdeaPalette.accent
        : RawdeaPalette.surface
    }

    var body: some View {

        Button(action: action) {

            HStack(
                spacing: RawdeaSpacing.sm
            ) {

                if isLoading {

                    ProgressView()
                        .tint(foregroundColor)
                        .accessibilityHidden(true)
                }

                Text(
                    isLoading
                    ? "\(title)…"
                    : title
                )
                .font(RawdeaTypography.button)
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
            }
            .frame(maxWidth: .infinity)
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
            .padding(
                .horizontal,
                RawdeaSpacing.md
            )
            .padding(
                .vertical,
                RawdeaSpacing.xs
            )
            .foregroundStyle(foregroundColor)
            .background(
                backgroundColor,
                in: RoundedRectangle(
                    cornerRadius:
                        RawdeaSpacing.buttonRadius,
                    style: .continuous
                )
            )
            .overlay {

                if !usesAccent {

                    RoundedRectangle(
                        cornerRadius:
                            RawdeaSpacing.buttonRadius,
                        style: .continuous
                    )
                    .strokeBorder(
                        RawdeaPalette.activityOutline,
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(
            isLoading
            ? "\(title), in progress"
            : title
        )
    }
}

// MARK: - Soft Surface Project Container

struct RawdeaProjectSurface<Content: View>: View {

    let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {

        content
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(RawdeaSpacing.cardPadding)
            .background(
                RawdeaPalette.surface,
                in: RoundedRectangle(
                    cornerRadius: RawdeaSpacing.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: RawdeaSpacing.cardRadius,
                    style: .continuous
                )
                .strokeBorder(
                    RawdeaPalette.projectOutline,
                    lineWidth: 1
                )
            }
    }
}

// MARK: - Quiet Outline Activity Container

struct RawdeaActivitySurface<Content: View>: View {

    let content: Content

    init(
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
    }

    var body: some View {

        content
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(RawdeaSpacing.cardPadding)
            .background(
                RawdeaPalette.canvas,
                in: RoundedRectangle(
                    cornerRadius: RawdeaSpacing.cardRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: RawdeaSpacing.cardRadius,
                    style: .continuous
                )
                .strokeBorder(
                    RawdeaPalette.activityOutline,
                    lineWidth: 1
                )
            }
    }
}

// MARK: - Bare Minimal Empty State

struct RawdeaEmptyState: View {

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    let symbol: String
    let title: String
    let message: String

    let actionTitle: String?
    let action: (() -> Void)?

    init(
        symbol: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {

        VStack(spacing: RawdeaSpacing.sm) {

            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: symbol)
                    .font(.system(.title, weight: .regular))
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(RawdeaTypography.sectionTitle)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(RawdeaTypography.secondary)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .multilineTextAlignment(.center)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            if let actionTitle,
               let action {

                Button(action: action) {
                    Text(actionTitle)
                        .font(RawdeaTypography.button)
                        .frame(
                            minWidth: RawdeaSpacing.minimumTouchTarget,
                            minHeight: RawdeaSpacing.minimumTouchTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(RawdeaPalette.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, RawdeaSpacing.lg)
        .padding(.vertical, RawdeaSpacing.xl)
    }
}

// MARK: - Accessible Inline Error

struct RawdeaInlineError: View {

    let message: String

    var body: some View {

        HStack(
            alignment: .firstTextBaseline,
            spacing: RawdeaSpacing.xs
        ) {

            Image(
                systemName: "exclamationmark.circle.fill"
            )
            .foregroundStyle(RawdeaPalette.danger)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Error. \(message)")
    }
}

