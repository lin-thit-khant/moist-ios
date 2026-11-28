//
//  RawdeaAuthComponents.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//

import SwiftUI

// MARK: - Welcome and sign-in

/// "Have an account? Log in" and similar text actions.
struct RawdeaAuthSwitchLabel: View {

    let prompt: String
    let action: String

    var body: some View {

        // The action stays on one line when text wraps.
        let unbroken = action.replacingOccurrences(of: " ", with: "\u{00A0}")

        return Text("\(prompt) \(Text(unbroken).fontWeight(.bold))")
            .font(RawdeaTypography.body)
            .foregroundStyle(RawdeaPalette.primaryText)
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

            Text("Read the \(Text("community guidelines and privacy information").underline()).")
                .font(RawdeaTypography.caption)
                .foregroundStyle(RawdeaPalette.secondaryText)
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

// MARK: - Terms agreement

/// Required tick before an account can be created.
struct RawdeaTermsAgreementRow: View {

    @Binding var isAccepted: Bool

    @State private var showsGuidelines = false
    @Environment(\.openURL) private var openURL

    static let statement =
        "I agree to the Terms and Community Guidelines. I know there is no tolerance for abusive content."

    private static let guidelinesURL = URL(string: "rawdea://community-guidelines")!

    /// Nil until a real HTTPS page is configured, so no dead link ships.
    static func termsLink(_ value: String) -> URL? {

        guard let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else {
            return nil
        }

        return url
    }

    static func attributedStatement(termsURL: URL?) -> AttributedString {

        var text = AttributedString(statement)

        func link(_ phrase: String, to url: URL) {
            guard let range = text.range(of: phrase) else { return }
            text[range].link = url
            text[range].underlineStyle = .single
        }

        link("Community Guidelines", to: guidelinesURL)

        if let termsURL {
            link("Terms", to: termsURL)
        }

        return text
    }

    var body: some View {

        let termsURL = Self.termsLink(RawdeaPublicContact.termsURL)

        HStack(alignment: .top, spacing: RawdeaSpacing.xxs) {

            Button {

                isAccepted.toggle()

            } label: {

                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(
                        isAccepted
                        ? RawdeaPalette.accent
                        : RawdeaPalette.secondaryText
                    )
                    .frame(
                        minWidth: RawdeaSpacing.minimumTouchTarget,
                        minHeight: RawdeaSpacing.minimumTouchTarget
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.statement)
            .accessibilityValue(isAccepted ? "Checked" : "Not checked")
            .accessibilityAddTraits(isAccepted ? [.isToggle, .isSelected] : .isToggle)
            .accessibilityAction(named: "Read Community Guidelines") {
                showsGuidelines = true
            }
            .accessibilityActions {
                if let termsURL {
                    Button("Read Terms") { openURL(termsURL) }
                }
            }

            // The checkbox already reads this text and offers its links.
            Text(Self.attributedStatement(termsURL: termsURL))
                .font(RawdeaTypography.secondary)
                .foregroundStyle(RawdeaPalette.primaryText)
                .tint(RawdeaPalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    maxWidth: .infinity,
                    minHeight: RawdeaSpacing.minimumTouchTarget,
                    alignment: .leading
                )
                .environment(\.openURL, OpenURLAction { url in
                    guard url == Self.guidelinesURL else {
                        return .systemAction
                    }
                    showsGuidelines = true
                    return .handled
                })
                .accessibilityHidden(true)
        }
        .sheet(isPresented: $showsGuidelines) {

            NavigationStack {

                SafetyInformationView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsGuidelines = false }
                        }
                    }
            }
        }
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
            .accessibilityLabel("Email address")
            .modifier(RawdeaAuthFieldSurface())
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
            .modifier(RawdeaAuthFieldSurface())
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

