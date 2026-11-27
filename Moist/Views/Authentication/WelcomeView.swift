//
//  WelcomeView.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import SwiftUI

struct WelcomeView: View {

    @ObservedObject var authViewModel:
        AuthViewModel

    @Environment(\.dynamicTypeSize)
    private var dynamicTypeSize

    var body: some View {

        GeometryReader { geometry in

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {

                    Spacer(minLength: 0)

                    introduction

                    Spacer(
                        minLength: RawdeaSpacing.xl
                    )

                    if let error =
                        authViewModel.errorMessage {

                        RawdeaInlineError(
                            message: error
                        )
                        .padding(.bottom, RawdeaSpacing.sm)
                    }

                    choices
                }
                .frame(maxWidth: 480, alignment: .leading)
                .padding(
                    .horizontal,
                    RawdeaSpacing.authInset
                )
                .padding(.top, RawdeaSpacing.md)
                .padding(.bottom, RawdeaSpacing.xxs)
                .frame(
                    minHeight: geometry.size.height
                )
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .toolbar(.hidden, for: .navigationBar)

        .onAppear {

            authViewModel.clearMessages()
        }
    }

    // MARK: - Introduction

    private var introduction: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.lg
        ) {

            RawdeaProjectLabMark()

            VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {

                Text("Every idea has a history.")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("Rawdea is where builders keep a dated record of what they are making. Notes, questions, progress and decisions, all in one Project.")
                    .font(RawdeaTypography.body)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            exampleTimeline
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, RawdeaSpacing.xl)
    }

    // An illustration, not anyone's real Project.
    private var exampleTimeline: some View {

        VStack(alignment: .leading, spacing: 0) {
            exampleRow("Today", "Progress", "Third firing done.", dot: RawdeaPalette.accent)
            exampleRow("18 Nov", "Decision", "Dropping the matte white glaze.", dot: nil)
            exampleRow("3 Nov", "Stage", "Moved to In progress", dot: RawdeaPalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, RawdeaSpacing.sm)
        .padding(.vertical, RawdeaSpacing.xs)
        .background(
            RawdeaPalette.surface,
            in: RoundedRectangle(cornerRadius: RawdeaSpacing.cardRadius)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example Project timeline: progress, a decision, and a stage change.")
    }

    private func exampleRow(
        _ date: String,
        _ kind: String,
        _ text: String,
        dot: Color?
    ) -> some View {

        HStack(alignment: .top, spacing: RawdeaSpacing.sm) {

            if !dynamicTypeSize.isAccessibilitySize {
                Text(date)
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .frame(width: RawdeaSpacing.minimumTouchTarget + RawdeaSpacing.xs, alignment: .trailing)

                Circle()
                    .fill(dot ?? RawdeaPalette.surface)
                    .overlay {
                        Circle().strokeBorder(dot ?? RawdeaPalette.secondaryText, lineWidth: 1.5)
                    }
                    .frame(width: RawdeaSpacing.xs + 1, height: RawdeaSpacing.xs + 1)
                    .padding(.top, RawdeaSpacing.xxs)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(dynamicTypeSize.isAccessibilitySize ? "\(date) · \(kind)" : kind)
                    .font(RawdeaTypography.metadata.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)
                Text(text)
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RawdeaSpacing.xs)
    }

    // MARK: - Sign-in choices

    // Apple and Google return here once they work.
    private var choices: some View {

        VStack(spacing: RawdeaSpacing.xs) {

            NavigationLink {

                SignUpView(
                    authViewModel: authViewModel
                )

            } label: {

                Text("Continue with email")
                    .font(RawdeaTypography.button)
                    .foregroundStyle(RawdeaPalette.onPrimaryFill)
                    .multilineTextAlignment(.center)
                    .padding(RawdeaSpacing.xs)
                    .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.authButtonHeight)
                    .background(
                        RawdeaPalette.primaryFill,
                        in: RoundedRectangle(cornerRadius: RawdeaSpacing.buttonRadius)
                    )
            }

            NavigationLink {

                LoginView(
                    authViewModel: authViewModel
                )

            } label: {

                RawdeaAuthSwitchLabel(
                    prompt: "Already have an account?",
                    action: "Log in"
                )
            }

            RawdeaAuthLegalLink()
        }
        .buttonStyle(.plain)
        .disabled(authViewModel.isLoading)
    }
}

// MARK: - Mark

private struct RawdeaProjectLabMark: View {

    var body: some View {
        ZStack {
            Circle().stroke(RawdeaPalette.accent, lineWidth: 3)
                .frame(width: 40, height: 40)
            Circle().stroke(RawdeaPalette.accent, lineWidth: 3)
                .frame(width: 13, height: 13)
                .offset(x: -5, y: -3)
            Circle().stroke(RawdeaPalette.accent, lineWidth: 3)
                .frame(width: 6, height: 6)
                .offset(x: 8, y: 7)
        }
        .frame(width: RawdeaSpacing.minimumTouchTarget, height: RawdeaSpacing.minimumTouchTarget)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        WelcomeView(authViewModel: AuthViewModel())
    }
}
