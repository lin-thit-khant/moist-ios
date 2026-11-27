//
//  RawdeaActivityCard.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//


import SwiftUI

/// One flat Activity row. Unread rows carry the accent dot.
struct RawdeaActivityCard: View {

    let notification: RawdeaNotification

    var isOpening: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {

        HStack(
            alignment: .top,
            spacing: RawdeaSpacing.sm
        ) {

            if !dynamicTypeSize.isAccessibilitySize {
                avatar
            }

            VStack(
                alignment: .leading,
                spacing: RawdeaSpacing.xxs
            ) {

                Text("\(Text(notification.subject).fontWeight(.semibold)) \(notification.action)")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = notification.detail {
                    Text(detail)
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                        .lineLimit(2)
                }

                Text(PostRowView.relativeAge(of: notification.createdAt, at: .now))
                    .font(RawdeaTypography.caption)
                    .foregroundStyle(RawdeaPalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isOpening {

                ProgressView()
                    .accessibilityHidden(true)

            } else if !notification.isRead {

                Circle()
                    .fill(RawdeaPalette.accent)
                    .frame(width: RawdeaSpacing.xs, height: RawdeaSpacing.xs)
                    .padding(.top, RawdeaSpacing.xs)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            minHeight: RawdeaSpacing.minimumTouchTarget,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? "Read" : "Unread")
    }

    @ViewBuilder
    private var avatar: some View {

        if notification.kind == .stageChange,
           let projectId = notification.projectId {
            RawdeaProjectAvatar(name: notification.subject)
        } else {
            RawdeaInitialAvatar(
                name: notification.actorName,
                size: RawdeaSpacing.avatarColumn
            )
        }
    }
}
