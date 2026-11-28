//
//  RawdeaInProgressGlow.swift
//  Rawdea
//

import SwiftUI

/// Wraps the In progress segment in its glow and dots. The bar sits
/// between the two dot layers, so it hides the dots passing behind it.
struct RawdeaInProgressGlow: ViewModifier {

    let stage: ProjectStage
    /// The Project's posts, or nil where the segment stays quiet.
    let postCount: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isVisible = false
    /// When the motion begins; later than now while a sweep runs.
    @State private var start = Date.distantPast

    private var style: InProgressMotion.Style {
        guard postCount != nil else { return .off }
        return InProgressMotion.style(
            stage: stage,
            reduceMotion: reduceMotion,
            isVisible: isVisible
        )
    }

    /// Room around the bar for the dots and glow.
    private static let reach: CGFloat = 16

    func body(content: Content) -> some View {

        content
            .background {
                layer { time in
                    halo(at: time)
                    dots(at: time, inFront: false)
                }
            }
            .overlay {
                layer { time in
                    Capsule()
                        .strokeBorder(
                            RawdeaPalette.accent.opacity(0.55 * (time.map(InProgressMotion.glow) ?? 1)),
                            lineWidth: 1
                        )
                    dots(at: time, inFront: true)
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onChange(of: stage) { _, new in
                if new == .inProgress {
                    start = Date().addingTimeInterval(InProgressMotion.sweep)
                }
            }
    }

    // Seconds since the motion began, or nil when it holds still.
    @ViewBuilder
    private func layer(
        @ViewBuilder content: @escaping (Double?) -> some View
    ) -> some View {

        switch style {

        case .off:
            EmptyView()

        case .still:
            ZStack { content(nil) }
                .allowsHitTesting(false)
                .accessibilityHidden(true)

        case .live:
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince(
                    max(start, .init(timeIntervalSinceReferenceDate: 0))
                )
                ZStack {
                    if time >= 0 {
                        content(time)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func halo(at time: Double?) -> some View {
        let breath = time.map(InProgressMotion.glow)
        // Still: radius 8 at 0.3. Live: swells to radius 14, spread 4, at 0.42.
        let opacity = breath.map { 0.42 * $0 } ?? 0.3
        let radius = breath.map { 7 * $0 } ?? 4
        let spread = breath.map { 4 * $0 } ?? 2

        return Capsule()
            .fill(RawdeaPalette.accent.opacity(opacity))
            .padding(-spread)
            .blur(radius: radius)
    }

    @ViewBuilder
    private func dots(at time: Double?, inFront: Bool) -> some View {

        if let time, let postCount {
            Canvas { context, size in
                let width = size.width - Self.reach * 2

                // The dots ease in rather than appearing at once.
                context.opacity = min(time / 0.3, 1)

                for dot in InProgressMotion.dots(count: postCount, width: width, time: time)
                where dot.isInFront == inFront {
                    let side = InProgressMotion.dotSize * dot.scale
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: Self.reach + dot.x - side / 2,
                            y: size.height / 2 + dot.offset - side / 2,
                            width: side,
                            height: side
                        )),
                        with: .color(RawdeaPalette.accent)
                    )
                }
            }
            .padding(-Self.reach)
        }
    }
}
