//
//  RawdeaHeldPostViews.swift
//  Rawdea
//

import SwiftUI

/// A plain outlined note: a title, one message and optional extras.
struct RawdeaNote<Extra: View>: View {

    let title: String
    let message: String
    @ViewBuilder var extra: Extra

    var body: some View {

        RawdeaActivitySurface {
            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

                    Text(title)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.primaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)

                extra
            }
        }
    }
}

/// Small grey text under a note.
struct RawdeaNoteDetail: View {

    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RawdeaTypography.metadata)
            .foregroundStyle(RawdeaPalette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A pill button: crimson for the main action, outlined otherwise.
struct RawdeaPillButton: View {

    let title: String
    var isPrimary = false
    var isWorking = false
    let action: () -> Void

    var body: some View {

        Button(action: action) {
            HStack(spacing: RawdeaSpacing.xs) {
                if isWorking {
                    ProgressView()
                        .tint(isPrimary ? RawdeaPalette.onAccent : RawdeaPalette.primaryText)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(RawdeaTypography.authorName)
            .foregroundStyle(isPrimary ? RawdeaPalette.onAccent : RawdeaPalette.primaryText)
            .padding(.horizontal, RawdeaSpacing.md)
            .padding(.vertical, RawdeaSpacing.xs)
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .background {
                if isPrimary {
                    shape.fill(RawdeaPalette.accent)
                } else {
                    shape.strokeBorder(RawdeaPalette.activityOutline)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }

    // A pill on one line; wrapped large text stays inside the corners.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RawdeaSpacing.lg)
    }
}
