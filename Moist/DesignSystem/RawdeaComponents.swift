//
//  RawdeaComponents.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI

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

            Image(systemName: symbol)
                .font(.system(.title, weight: .regular))
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
                .accessibilityHidden(true)

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

                Button(actionTitle, action: action)
                    .font(RawdeaTypography.button)
                    .tint(RawdeaPalette.accent)
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
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

