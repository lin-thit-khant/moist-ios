//
//  ContributedToSection.swift
//  Rawdea
//

import SwiftUI

/// Other people's Projects this person helped with. Hidden when empty.
struct ContributedToSection: View {

    let userId: UUID

    @State private var projects: [ContributedProject] = []

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

            if !projects.isEmpty {

                Text("Contributed to")
                    .font(RawdeaTypography.secondary.weight(.medium))
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .accessibilityAddTraits(.isHeader)

                ForEach(projects) { item in
                    Button {
                        openPostRoute?(.project(item.projectId))
                    } label: {
                        HStack(spacing: RawdeaSpacing.sm) {
                            RawdeaProjectAvatar(name: item.projectName)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(item.projectName)
                                    .font(RawdeaTypography.authorName)
                                    .foregroundStyle(RawdeaPalette.primaryText)
                                Text(item.detail)
                                    .font(RawdeaTypography.metadata)
                                    .foregroundStyle(RawdeaPalette.secondaryText)
                            }
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, RawdeaSpacing.xxs)
                        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens Project")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A failed load only leaves the list out.
        .task(id: userId) {
            if let loaded = try? await CollaborationService()
                .fetchContributedTo(userId: userId) {
                projects = loaded
            }
        }
    }
}
