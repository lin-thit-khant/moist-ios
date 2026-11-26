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

    var body: some View {

        GeometryReader { geometry in

            ScrollView {

                VStack(
                    spacing: RawdeaSpacing.lg
                ) {

                    Spacer(
                        minLength: RawdeaSpacing.xl
                    )

                    RawdeaAuthBrand()

                    Spacer(
                        minLength: RawdeaSpacing.xl
                    )

                    accountActions

                    safetyLink
                }
                .frame(maxWidth: 480)
                .padding(
                    .horizontal,
                    RawdeaSpacing.screenInset
                )
                .padding(
                    .vertical,
                    RawdeaSpacing.lg
                )
                .frame(
                    minHeight: geometry.size.height
                )
                .frame(maxWidth: .infinity)
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)

        .onAppear {

            authViewModel.clearMessages()
        }
    }

    // MARK: - Account actions

    private var accountActions: some View {

        VStack(
            spacing: RawdeaSpacing.sm
        ) {

            NavigationLink {

                SignUpView(
                    authViewModel: authViewModel
                )

            } label: {

                Text("Create account")
                    .font(
                        RawdeaTypography.button
                    )
                    .foregroundStyle(
                        RawdeaPalette.onPrimaryFill
                    )
                    .multilineTextAlignment(.center)
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                    .padding(
                        .vertical,
                        RawdeaSpacing.xs
                    )
                    .background(
                        RawdeaPalette.primaryFill,
                        in: RoundedRectangle(
                            cornerRadius:
                                RawdeaSpacing.buttonRadius
                        )
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            NavigationLink {

                LoginView(
                    authViewModel: authViewModel
                )

            } label: {

                Text("Log in")
                    .font(
                        RawdeaTypography.button
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .multilineTextAlignment(.center)
                    .frame(
                        maxWidth: .infinity,
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                    .padding(
                        .vertical,
                        RawdeaSpacing.xs
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
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .disabled(authViewModel.isLoading)
    }

    // MARK: - Public safety information

    private var safetyLink: some View {

        NavigationLink {

            SafetyInformationView()

        } label: {

            Label(
                "Community Guidelines & Support",
                systemImage: "shield"
            )
            .font(RawdeaTypography.metadata)
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
            .multilineTextAlignment(.center)
            .frame(
                maxWidth: .infinity,
                minHeight:
                    RawdeaSpacing.minimumTouchTarget
            )
        }
        .buttonStyle(.plain)
        .disabled(authViewModel.isLoading)
    }
}
