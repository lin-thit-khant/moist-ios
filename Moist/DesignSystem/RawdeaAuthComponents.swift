//
//  RawdeaAuthComponents.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//

import SwiftUI
import UIKit

// MARK: - Welcome and sign-in style

/// A faint grid that fades out toward the bottom. Decorative.
struct RawdeaAuthGrid: View {

    private static let step: CGFloat = 39

    var body: some View {

        Canvas { graphics, size in

            var lines = Path()

            for x in stride(from: 0, through: size.width, by: Self.step) {
                lines.addRect(CGRect(x: x, y: 0, width: 1, height: size.height))
            }

            for y in stride(from: 0, through: size.height, by: Self.step) {
                lines.addRect(CGRect(x: 0, y: y, width: size.width, height: 1))
            }

            graphics.fill(lines, with: .color(RawdeaPalette.authLine))
        }
        .opacity(0.45)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .clear, location: 0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The large heading on welcome and sign-in screens.
struct RawdeaAuthHeadline: View {

    let text: String

    @ScaledMetric private var size: CGFloat

    private let largest: CGFloat

    init(_ text: String, size: CGFloat, largest: CGFloat) {
        self.text = text
        self.largest = largest
        _size = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    var body: some View {

        // Capped so long words do not break at accessibility sizes.
        Text(text)
            .font(.system(size: min(size, largest), weight: .bold))
            .tracking(-min(size, largest) * 0.03)
            .foregroundStyle(RawdeaPalette.authText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Small uppercase monospaced label.
struct RawdeaAuthMonoLabel: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {

        Text(text)
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(RawdeaPalette.authSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The 52 pt sign-in choices on the welcome screen.
struct RawdeaAuthChoiceLabel: View {

    enum Look {
        case apple
        case email
        case outline
    }

    let title: String
    var symbol: String?
    let look: Look
    var isLoading = false

    @Environment(\.dynamicTypeSize) private var typeSize

    private var foreground: Color {

        switch look {
        case .apple: RawdeaPalette.onAppleButtonFill
        case .email: RawdeaPalette.onAuthAccent
        case .outline: RawdeaPalette.authText
        }
    }

    private var fill: Color {

        switch look {
        case .apple: RawdeaPalette.appleButtonFill
        case .email: RawdeaPalette.authAccent
        case .outline: RawdeaPalette.authCanvas
        }
    }

    private var shape: RoundedRectangle {

        RoundedRectangle(
            cornerRadius: RawdeaSpacing.authButtonRadius,
            style: .continuous
        )
    }

    var body: some View {

        HStack(spacing: RawdeaSpacing.xs) {

            if isLoading {

                ProgressView()
                    .tint(foreground)

            } else if let symbol, !typeSize.isAccessibilitySize {

                // Large text needs the whole width.

                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }

            Text(title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(RawdeaTypography.button)
        .foregroundStyle(foreground)
        .padding(.horizontal, RawdeaSpacing.md)
        .padding(.vertical, RawdeaSpacing.xs)
        .frame(
            maxWidth: .infinity,
            minHeight: RawdeaSpacing.authButtonHeight
        )
        .background(fill, in: shape)
        .overlay {

            if look == .outline {

                shape
                    .strokeBorder(RawdeaPalette.authLine, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }
}

/// "Have an account? Log in" and similar text actions.
struct RawdeaAuthSwitchLabel: View {

    let prompt: String
    let action: String

    var body: some View {

        // The action stays on one line when text wraps.
        let unbroken = action.replacingOccurrences(of: " ", with: "\u{00A0}")

        return Text("\(prompt) \(Text(unbroken).fontWeight(.bold))")
            .font(RawdeaTypography.body)
            .foregroundStyle(RawdeaPalette.authText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                minHeight: RawdeaSpacing.minimumTouchTarget
            )
            .contentShape(Rectangle())
            .accessibilityLabel("\(prompt) \(action)")
    }
}

/// Opens the community guidelines and privacy information.
struct RawdeaAuthLegalLink: View {

    var body: some View {

        NavigationLink {

            SafetyInformationView()

        } label: {

            Text("By continuing you agree to the \(Text("Terms").underline()) and \(Text("Privacy Policy").underline()).")
                .font(RawdeaTypography.caption)
                .foregroundStyle(RawdeaPalette.authSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    minHeight: RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens community guidelines and privacy information")
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

    /// When set, the label sits inside an outlined box.
    var boxedTitle: String?

    func body(
        content: Content
    ) -> some View {

        if let boxedTitle {

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                Text(boxedTitle)
                    .font(RawdeaTypography.caption)
                    .foregroundStyle(
                        RawdeaPalette.authSecondaryText
                    )
                    .padding(.top, RawdeaSpacing.xs)
                    .accessibilityHidden(true)

                content
                    .font(RawdeaTypography.body)
                    .foregroundStyle(
                        RawdeaPalette.authText
                    )
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
            }
            .padding(
                .horizontal,
                RawdeaSpacing.sm
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius:
                        RawdeaSpacing.authButtonRadius
                )
                .strokeBorder(
                    RawdeaPalette.authLine,
                    lineWidth: 1.5
                )
                .allowsHitTesting(false)
            }

        } else {

            plain(content)
        }
    }

    private func plain(
        _ content: Content
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

    var isBoxed = false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            if !isBoxed {

                Text("Email address")
                    .font(RawdeaTypography.authorName)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .accessibilityHidden(true)
            }

            TextField(
                "you@example.com",
                text: $email
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel("Email address")
            .modifier(
                RawdeaAuthFieldSurface(
                    boxedTitle:
                        isBoxed ? "Email address" : nil
                )
            )
        }
    }
}

// MARK: - Password input

struct RawdeaPasswordField: View {

    let title: String

    @Binding var password: String

    var isNewPassword = false

    var isBoxed = false

    @State private var isVisible = false

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            if !isBoxed {

                Text(title)
                    .font(RawdeaTypography.authorName)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .accessibilityHidden(true)
            }

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
                    // Keeps the symbol inside its 44 pt target.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                RawdeaAuthFieldSurface(
                    boxedTitle: isBoxed ? title : nil
                )
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

