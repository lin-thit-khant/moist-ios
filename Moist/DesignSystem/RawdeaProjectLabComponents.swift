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

/// Three segments: finished stages accented, the current one white
/// with an outline. The stage names carry the meaning without color.
struct RawdeaStageTrack: View {

    let stage: ProjectStage
    /// Each change makes the Early segment swell and glow once.
    var earlyPulse = 0
    /// The Project's posts, to bring the In progress segment to life.
    var livePostCount: Int? = nil
    /// How a shipped Project's joined line looks now, on its page.
    var shipped: ShippedArrival.Frame? = nil
    /// Reduce Motion fades the joined line in.
    var shippedOpacity = 1.0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Until the dots arrive, the track still reads In progress.
        let stage = shipped?.hasArrived == false ? .inProgress : self.stage
        let stages = ProjectStage.allCases
        let current = stages.firstIndex(of: stage) ?? 0

        VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

            HStack(spacing: RawdeaSpacing.xs) {
                ForEach(stages.indices, id: \.self) { index in
                    if index == 0 {
                        segment(isReached: true, isDone: index < current)
                            .keyframeAnimator(
                                initialValue: 0.0,
                                trigger: earlyPulse
                            ) { [isStill = reduceMotion] bar, pulse in
                                bar
                                    .scaleEffect(y: isStill ? 1 : 1 + 1.1 * pulse)
                                    // After the scale, so the glow is not stretched.
                                    .shadow(
                                        color: RawdeaPalette.accent.opacity(isStill ? 0 : 0.55 * pulse),
                                        radius: 10 * pulse
                                    )
                            } keyframes: { _ in
                                CubicKeyframe(1, duration: 0.13)
                                CubicKeyframe(0, duration: 0.29)
                            }
                            .anchorPreference(key: RawdeaEarlyBarKey.self, value: .bounds) { $0 }
                            .overlay(alignment: .trailing) { bridge(0) }
                            // The bridge reaches over the next segment.
                            .zIndex(2)
                    } else if stages[index] == .inProgress {
                        segment(isReached: index <= current, isDone: index < current)
                            .modifier(RawdeaInProgressGlow(
                                stage: stage,
                                // Shipping stops the dots at once.
                                postCount: shipped == nil ? livePostCount : nil
                            ))
                            .overlay { shippedFill(shipped?.inProgressFill, sweeps: false) }
                            .overlay(alignment: .trailing) { bridge(1) }
                            .anchorPreference(key: RawdeaStageBarsKey.self, value: .bounds) { [index: $0] }
                            // Its dots pass over the neighbouring segments.
                            .zIndex(1)
                    } else {
                        segment(isReached: index <= current, isDone: index < current)
                            .overlay { shippedFill(shipped?.shippedFill, sweeps: true) }
                            .anchorPreference(key: RawdeaStageBarsKey.self, value: .bounds) { [index: $0] }
                    }
                }
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.7), value: stage)
            // The one glow along the joined line.
            .background {
                if let glow = shipped?.glow, glow > 0 {
                    Capsule()
                        .fill(RawdeaPalette.accent.opacity(0.45 * glow))
                        .padding(-4)
                        .blur(radius: 7)
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

    // Crimson laid over a segment while a Project ships and after.
    @ViewBuilder
    private func shippedFill(_ amount: Double?, sweeps: Bool) -> some View {
        if let amount {
            let curve = UnitCurve.bezier(
                startControlPoint: UnitPoint(x: 0.3, y: 0.9),
                endControlPoint: UnitPoint(x: 0.3, y: 1)
            )
            Capsule()
                .fill(RawdeaPalette.accent)
                .scaleEffect(x: sweeps ? curve.value(at: amount) : 1, anchor: .leading)
                .opacity((sweeps ? 1 : amount) * shippedOpacity)
        }
    }

    @ViewBuilder
    private func bridge(_ index: Int) -> some View {
        if let progress = shipped?.bridges[index], progress > 0 {
            RawdeaStageBridge(progress: progress)
                .opacity(shippedOpacity)
        }
    }

    // Both fills stay in place and widen from the leading edge, so a
    // new stage sweeps white and the finished one sweeps crimson.
    private func segment(isReached: Bool, isDone: Bool) -> some View {
        ZStack {
            Capsule()
                .fill(RawdeaPalette.divider)
            Capsule()
                .fill(RawdeaPalette.stageCurrent)
                .overlay {
                    Capsule().strokeBorder(RawdeaPalette.stageOutline, lineWidth: 1)
                }
                .scaleEffect(x: isReached ? 1 : 0, anchor: .leading)
            Capsule()
                .fill(RawdeaPalette.accent)
                .scaleEffect(x: isDone ? 1 : 0, anchor: .leading)
        }
        .frame(height: 5)
    }
}

// MARK: - Chip

/// A selectable pill for kinds and filters.
struct RawdeaChip: View {

    let title: String
    var symbol: String? = nil
    /// A name whose initial sits in a small circle.
    var avatar: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: RawdeaSpacing.xxs) {
                if let avatar {
                    RawdeaInitialAvatar(
                        name: avatar,
                        size: RawdeaSpacing.lg,
                        font: RawdeaTypography.caption.weight(.bold)
                    )
                }
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

// MARK: - Wrapping

/// Lays views in rows, starting a new row when one is full.
struct RawdeaWrapLayout: Layout {

    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = proposal.width ?? .infinity
        let frames = frames(in: width, subviews: subviews)
        return CGSize(
            width: proposal.width ?? (frames.map(\.maxX).max() ?? 0),
            height: frames.map(\.maxY).max() ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for (subview, frame) in zip(subviews, frames(in: bounds.width, subviews: subviews)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(in width: CGFloat, subviews: Subviews) -> [CGRect] {
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0

        return subviews.map { subview in
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + rowHeight)
                rowHeight = 0
            }
            let frame = CGRect(origin: origin, size: size)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            return frame
        }
    }
}
