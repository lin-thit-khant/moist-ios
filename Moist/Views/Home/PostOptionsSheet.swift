//
//  PostOptionsSheet.swift
//  Rawdea
//

import SwiftUI

/// One action offered for a post.
struct PostOption: Identifiable {
    let title: String
    let symbol: String
    var isDestructive = false
    let action: () -> Void

    var id: String { title }
}

/// A short bottom sheet of post actions.
struct PostOptionsSheet: View {

    let options: [PostOption]
    let onSelect: (PostOption) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let rowHeight: CGFloat = 52

    private var detents: Set<PresentationDetent> {
        if dynamicTypeSize.isAccessibilitySize {
            return [.medium, .large]
        }
        // Rows grow a little with the larger standard text sizes.
        let rows = CGFloat(options.count) * (Self.rowHeight + RawdeaSpacing.xs)
        return [.height(rows + RawdeaSpacing.xl * 2), .large]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: RawdeaSpacing.xs) {
                ForEach(options) { option in
                    row(option)
                }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
            .padding(.top, RawdeaSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(RawdeaPalette.canvas)
    }

    private func row(_ option: PostOption) -> some View {
        Button {
            onSelect(option)
        } label: {
            HStack(spacing: RawdeaSpacing.sm) {
                Text(option.title)
                    .font(RawdeaTypography.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: option.symbol)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(
                option.isDestructive
                ? RawdeaPalette.danger
                : RawdeaPalette.primaryText
            )
            .padding(.horizontal, RawdeaSpacing.md)
            .padding(.vertical, RawdeaSpacing.xs)
            .frame(minHeight: Self.rowHeight)
            .background(
                RawdeaPalette.surface,
                in: RoundedRectangle(cornerRadius: RawdeaSpacing.cardRadius)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
