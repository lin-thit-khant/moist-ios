//
//  RawdeaProjectLabComponents.swift
//  Rawdea
//

import SwiftUI

extension PostKind {

    var symbol: String {
        switch self {
        case .note: "doc.text"
        case .question: "questionmark.circle"
        case .progress: "chart.line.uptrend.xyaxis"
        case .decision: "flag"
        }
    }

    var filterTitle: String {
        switch self {
        case .note: "Notes"
        case .question: "Questions"
        case .progress: "Progress"
        case .decision: "Decisions"
        }
    }
}

// MARK: - Kind label

/// "Question · Open", above a post's words.
struct RawdeaKindLabel: View {

    let post: Post

    private var text: String {
        guard post.kind == .question else { return post.kind.title }
        return "\(post.kind.title) · \(post.bestReplyId == nil ? "Open" : "Answered")"
    }

    var body: some View {
        // A List row would give a Label a wide icon column.
        HStack(alignment: .firstTextBaseline, spacing: RawdeaSpacing.xxs) {
            Image(systemName: post.kind.symbol)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(RawdeaTypography.metadata.weight(.medium))
        .foregroundStyle(RawdeaPalette.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

// MARK: - Stage

/// Three segments: finished stages dark, the current one accented.
/// The stage names carry the meaning without color.
struct RawdeaStageTrack: View {

    let stage: ProjectStage

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let stages = ProjectStage.allCases
        let current = stages.firstIndex(of: stage) ?? 0

        VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

            HStack(spacing: RawdeaSpacing.xs) {
                ForEach(stages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index < current
                            ? RawdeaPalette.primaryText
                            : index == current
                                ? RawdeaPalette.accent
                                : RawdeaPalette.divider)
                        .frame(height: 4)
                }
            }

            // Large text has no room for three columns; the
            // line under the track already names the stage.
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: RawdeaSpacing.xs) {
                    ForEach(stages, id: \.self) { item in
                        Text(item.title)
                            .font(RawdeaTypography.caption.weight(item == stage ? .semibold : .regular))
                            .foregroundStyle(item == stage
                                ? RawdeaPalette.primaryText
                                : RawdeaPalette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stage: \(stage.title)")
    }
}

// MARK: - Chip

/// A selectable pill for kinds and filters.
struct RawdeaChip: View {

    let title: String
    var symbol: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RawdeaSpacing.xxs) {
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(RawdeaTypography.secondary.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(RawdeaPalette.primaryText)
            .padding(.horizontal, RawdeaSpacing.sm)
            .padding(.vertical, RawdeaSpacing.xs)
            .background(isSelected ? RawdeaPalette.surface : RawdeaPalette.canvas, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isSelected
                    ? RawdeaPalette.primaryText
                    : RawdeaPalette.activityOutline)
            }
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
