//
//  RawdeaDesignPreviewView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


#if DEBUG

import SwiftUI

struct RawdeaDesignPreviewView: View {

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    @State private var activationCount = 0

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.lg
            ) {

                // MARK: - Heading

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    Text("Rawdea UI Kit")
                        .font(
                            RawdeaTypography.screenTitle
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )

                    Text("Milestone 14 · Batch 1")
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                }

                // MARK: - Environment

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    Text("Current environment")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    Text(
                        "Mode: \(colorScheme == .dark ? "Dark" : "Light")"
                    )

                    Text(
                        "Contrast: \(colorSchemeContrast == .increased ? "Increased" : "Standard")"
                    )
                }
                .font(RawdeaTypography.secondary)
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )

                // MARK: - Text

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    Text("Reading First")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    Text(
                        """
                        Every idea starts somewhere.

                        Rawdea makes room for thoughts \
                        that are still taking shape.
                        """
                    )
                    .font(RawdeaTypography.postBody)

                    Text("Example post · 2 hours ago")
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                }
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )

                Divider()

                // MARK: - Soft Surface

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.sm
                ) {

                    Text("Soft Surface Project")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    RawdeaProjectSurface {

                        HStack(
                            alignment: .top,
                            spacing: RawdeaSpacing.sm
                        ) {

                            Image(systemName: "folder")
                                .foregroundStyle(
                                    RawdeaPalette.accent
                                )
                                .accessibilityHidden(true)

                            VStack(
                                alignment: .leading,
                                spacing: RawdeaSpacing.xs
                            ) {

                                Text("Creative Notes")
                                    .font(
                                        RawdeaTypography.authorName
                                    )
                                    .foregroundStyle(
                                        RawdeaPalette.primaryText
                                    )

                                Text("8 posts · Pinned Project")
                                    .font(
                                        RawdeaTypography.metadata
                                    )
                                    .foregroundStyle(
                                        RawdeaPalette.secondaryText
                                    )
                            }

                            Spacer(minLength: 0)

                            Image(
                                systemName: "chevron.right"
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                            .accessibilityHidden(true)
                        }
                    }
                }

                // MARK: - Quiet Outline

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.sm
                ) {

                    Text("Quiet Outline Activity")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    RawdeaActivitySurface {

                        HStack(spacing: RawdeaSpacing.sm) {

                            Image(systemName: "bell")
                                .foregroundStyle(
                                    RawdeaPalette.secondaryText
                                )
                                .accessibilityHidden(true)

                            VStack(
                                alignment: .leading,
                                spacing: RawdeaSpacing.xxs
                            ) {

                                Text("New activity")
                                    .font(
                                        RawdeaTypography.authorName
                                    )

                                Text("Someone commented on your post")
                                    .font(
                                        RawdeaTypography.metadata
                                    )
                                    .foregroundStyle(
                                        RawdeaPalette.secondaryText
                                    )
                            }

                            Spacer(minLength: 0)

                            Circle()
                                .fill(
                                    RawdeaPalette.secondaryText
                                )
                                .frame(
                                    width: 7,
                                    height: 7
                                )
                                .accessibilityHidden(true)
                        }
                    }
                }

                // MARK: - Button

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.sm
                ) {

                    Text("Quiet Native Button")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    RawdeaPrimaryButton(
                        "Test Primary Action"
                    ) {
                        activationCount += 1
                    }

                    Text(
                        "Button activated \(activationCount) times"
                    )
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

                    RawdeaPrimaryButton(
                        "Publishing",
                        isLoading: true
                    ) {
                        // Intentionally disabled preview state.
                    }
                }

                // MARK: - Errors

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.sm
                ) {

                    Text("Accessible Error")
                        .font(
                            RawdeaTypography.sectionTitle
                        )

                    RawdeaInlineError(
                        message: "Couldn't save. Please try again."
                    )
                }

                Divider()

                // MARK: - Empty State

                RawdeaEmptyState(
                    symbol: "text.bubble",
                    title: "No posts yet",
                    message:
                        "Posts will appear here when they're available.",
                    actionTitle: "Test Action"
                ) {
                    activationCount += 1
                }

            }
            .padding(RawdeaSpacing.screenInset)
        }
        .background(
            RawdeaPalette.canvas.ignoresSafeArea()
        )
        .navigationTitle("Design Preview")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif

