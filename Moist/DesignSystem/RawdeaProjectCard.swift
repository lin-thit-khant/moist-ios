//
//  RawdeaProjectCard.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//


import SwiftUI

struct RawdeaProjectCard: View {

    let project: Project
    let preview: String?
    let showsOwnerStatus: Bool

    init(
        project: Project,
        preview: String? = nil,
        showsOwnerStatus: Bool = false
    ) {
        self.project = project
        self.preview = preview
        self.showsOwnerStatus = showsOwnerStatus
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xs
        ) {

            HStack(
                alignment: .firstTextBaseline,
                spacing: RawdeaSpacing.xs
            ) {

                Text(project.name)
                    .font(RawdeaTypography.sectionTitle)
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )

                if project.isPinned {

                    Image(systemName: "pin.fill")
                        .font(RawdeaTypography.caption)
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .accessibilityLabel("Pinned")
                }

                Spacer(minLength: 0)
            }

            if let preview,
               !preview.trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {

                Text(preview)
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .lineLimit(3)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }

            if showsOwnerStatus {

                HStack(
                    spacing: RawdeaSpacing.sm
                ) {

                    if project.isHidden {

                        Label(
                            "Hidden",
                            systemImage: "eye.slash"
                        )
                    }

                    if project.isArchived {

                        Label(
                            "Archived",
                            systemImage: "archivebox"
                        )
                    }
                }
                .font(RawdeaTypography.caption)
                .foregroundStyle(
                    RawdeaPalette.secondaryText
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(
            children: .combine
        )
    }
}
