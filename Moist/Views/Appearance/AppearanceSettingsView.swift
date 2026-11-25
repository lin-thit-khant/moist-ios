//
//  AppearanceSettingsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 21/11/2569 BE.
//


import SwiftUI

struct AppearanceSettingsView: View {

    @AppStorage(RawdeaAppearance.storageKey)
    private var selectedAppearance =
        RawdeaAppearance.system.rawValue

    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.colorSchemeContrast)
    private var colorSchemeContrast

    var body: some View {

        Form {

            Section {

                Picker(
                    "Appearance",
                    selection: $selectedAppearance
                ) {

                    ForEach(RawdeaAppearance.allCases) { mode in

                        Label(
                            mode.title,
                            systemImage: mode.symbol
                        )
                        .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)

            } header: {

                Text("Appearance")

            } footer: {

                Text(
                    """
                    System follows your iPhone's appearance setting. \
                    Your selection is saved on this device.
                    """
                )
            }

            Section("Current Appearance") {

                LabeledContent(
                    "Effective Mode",
                    value: colorScheme == .dark
                    ? "Dark"
                    : "Light"
                )

                LabeledContent(
                    "Increase Contrast",
                    value: colorSchemeContrast == .increased
                    ? "On"
                    : "Off"
                )
            }

            Section("Preview") {

                HStack(spacing: RawdeaSpacing.md) {

                    Circle()
                        .fill(RawdeaPalette.accent)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(
                        alignment: .leading,
                        spacing: RawdeaSpacing.xxs
                    ) {

                        Text("Rawdea")
                            .font(
                                RawdeaTypography.sectionTitle
                            )
                            .foregroundStyle(
                                RawdeaPalette.primaryText
                            )

                        Text("Signature accent")
                            .font(
                                RawdeaTypography.metadata
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                    }
                }
                .padding(.vertical, RawdeaSpacing.xs)
            }
        }
        .navigationTitle("Appearance")
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
    }
}

