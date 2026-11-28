//
//  RawdeaShippedMotion.swift
//  Rawdea
//

import SwiftUI

/// Where each stage segment sits, by its index.
struct RawdeaStageBarsKey: PreferenceKey {

    static let defaultValue: [Int: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [Int: Anchor<CGRect>],
        nextValue: () -> [Int: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { first, _ in first }
    }
}

/// The bridge that closes the gap after a segment.
struct RawdeaStageBridge: View {

    let progress: Double

    var body: some View {
        let curve = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.3, y: 1.3),
            endControlPoint: UnitPoint(x: 0.5, y: 1)
        )
        let shape = ShippedArrival.bridgeShape(at: curve.value(at: progress))
        // Past each bar's rounded end, so no notch shows.
        let overlap: CGFloat = 3
        let width = RawdeaSpacing.xs + overlap * 2

        // Round while it swells, square once it is part of the line.
        RoundedRectangle(cornerRadius: progress < 1 ? 2.5 : 0)
            .fill(RawdeaPalette.accent)
            .frame(width: width, height: 5)
            .scaleEffect(x: shape.width, y: shape.thickness)
            .offset(x: width - overlap)
    }
}

/// The dots in flight between the In progress and Shipped bars.
struct RawdeaShippedDots: View {

    let arrival: ShippedArrival
    let startedAt: Date
    let from: CGRect
    let to: CGRect

    /// Room around the bars for the arcs.
    private static let reach: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    draw(
                        in: &context,
                        elapsed: timeline.date.timeIntervalSince(startedAt)
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height + Self.reach * 2)
            .offset(y: -Self.reach)
        }
    }

    private func draw(in context: inout GraphicsContext, elapsed: Double) {
        let rise = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.4, y: 0),
            endControlPoint: UnitPoint(x: 0.2, y: 1)
        )
        let fall = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.6, y: 0),
            endControlPoint: UnitPoint(x: 0.9, y: 0.6)
        )
        let count = Double(arrival.arcs.count)

        for (index, arc) in arrival.arcs.enumerated() {
            let time = (elapsed - arc.start) / arc.duration
            // A dot shows from its lift-off to its landing.
            guard time > 0, time < 1 else { continue }

            let slot = (Double(index) + 0.5) / count
            let x0 = from.minX + from.width * slot
            let dx = to.minX + to.width * slot - x0

            var along = 0.0
            var height = 0.0
            var scale = 1.0

            if time >= arc.peakTime {
                let part = fall.value(at: (time - arc.peakTime) / (1 - arc.peakTime))
                along = arc.peakPosition + (1 - arc.peakPosition) * part
                height = arc.peakOffset * (1 - part)
                scale = arc.peakScale + (0.3 - arc.peakScale) * part
            } else {
                let part = rise.value(at: time / arc.peakTime)
                along = arc.peakPosition * part
                height = arc.peakOffset * part
                scale = 1 + (arc.peakScale - 1) * part
            }

            let side = 6 * scale
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x0 + dx * along - side / 2,
                    y: from.midY + Self.reach + height - side / 2,
                    width: side,
                    height: side
                )),
                with: .color(RawdeaPalette.accent)
            )
        }
    }
}
