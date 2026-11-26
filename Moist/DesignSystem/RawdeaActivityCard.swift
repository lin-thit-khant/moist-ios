//
//  RawdeaActivityCard.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//


import SwiftUI

struct RawdeaActivityCard: View {

    let notification: RawdeaNotification

    var isOpening: Bool = false

    private var isUnread: Bool {
        !notification.isRead
    }

    var body: some View {

        RawdeaActivitySurface {

            HStack(
                alignment: .top,
                spacing: RawdeaSpacing.sm
            ) {

                Image(
                    systemName:
                        notification.kind.systemImage
                )
                .font(.system(.title3))
                .foregroundStyle(
                    isUnread
                    ? RawdeaPalette.primaryText
                    : RawdeaPalette.secondaryText
                )
                .frame(
                    minWidth: 36,
                    minHeight: 36
                )
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    Text(notification.message)
                        .font(
                            RawdeaTypography.body
                        )
                        .fontWeight(
                            isUnread
                            ? .semibold
                            : .regular
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Text(
                        notification.createdAt,
                        style: .relative
                    )
                    .font(
                        RawdeaTypography.caption
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

                    if isUnread {

                        Label(
                            "Unread",
                            systemImage: "circle.fill"
                        )
                        .font(
                            RawdeaTypography.caption
                        )
                        .foregroundStyle(
                            RawdeaPalette.primaryText
                        )

                    } else {

                        Text("Read")
                            .font(
                                RawdeaTypography.caption
                            )
                            .foregroundStyle(
                                RawdeaPalette.secondaryText
                            )
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                if isOpening {

                    ProgressView()
                        .accessibilityHidden(true)

                } else {

                    Image(systemName: "chevron.right")
                        .font(
                            RawdeaTypography.caption
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .accessibilityHidden(true)
                }
            }
            .frame(
                minHeight:
                    RawdeaSpacing.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .accessibilityElement(
            children: .combine
        )
    }
}
