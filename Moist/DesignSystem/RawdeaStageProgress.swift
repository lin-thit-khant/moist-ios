//
//  RawdeaStageProgress.swift
//  Rawdea
//

import SwiftUI

/// A Project page's stage track and summary line. A new stage sweeps
/// along the track; an Early Project can play its posts arriving.
struct RawdeaStageProgress: View {

    let stage: ProjectStage
    let summary: String
    /// The true number of posts, one In progress dot each.
    var postCount = 0
    /// The number of posts to play arriving, or nil.
    var arrivalCount: Int? = nil
    var onArrivalEnd: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dots: [Dot] = []
    @State private var startedAt = Date.distantPast
    @State private var landed = 0
    /// Only counts up, so resetting `landed` cannot pulse the bar.
    @State private var pulse = 0
    @State private var finished = 0
    @State private var softFade = false

    // Shipping
    @State private var shipping: Shipping?
    /// The stage already shown, so a new one is not drawn finished
    /// before its play begins.
    @State private var shownStage: ProjectStage?
    @State private var previousSummary = ""
    @State private var shippedOpacity = 1.0
    /// Reduce Motion: the joined line is still fading in.
    @State private var isFading = false
    @State private var taps = 0
    @State private var shippedSuccess = 0

    private struct Shipping: Equatable {
        let id = UUID()
        let arrival: ShippedArrival
        let startedAt: Date

        static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    }

    // nil unless shipped. At rest, one joined crimson line.
    private func shippedFrame(at date: Date) -> ShippedArrival.Frame? {
        guard stage == .shipped else { return nil }
        if let shipping {
            return shipping.arrival.frame(at: date.timeIntervalSince(shipping.startedAt))
        }
        if isNewlyShipped && !reduceMotion {
            return .start
        }
        var frame = ShippedArrival.Frame.rest
        frame.hasArrived = !isFading && !isNewlyShipped
        return frame
    }

    /// Shipped, but its change has not been picked up yet.
    private var isNewlyShipped: Bool {
        guard stage == .shipped, shipping == nil, !isFading,
              let shownStage else { return false }
        return shownStage != .shipped
    }

    private struct Dot {
        /// Where along the Early bar it lands, from 0 to 1.
        let position: Double
        let jitter: Double
        /// Where it starts, on an ellipse around that point.
        let offset: CGSize
    }

    private var isPlaying: Bool { !dots.isEmpty }

    var body: some View {

        TimelineView(.animation(paused: shipping == nil)) { timeline in

            let shipped = shippedFrame(at: timeline.date)
            let isAwaited = shipped?.hasArrived == false

            VStack(alignment: .leading, spacing: RawdeaSpacing.sm) {

                RawdeaStageTrack(
                    stage: stage,
                    earlyPulse: pulse,
                    livePostCount: postCount,
                    shipped: shipped,
                    shippedOpacity: isNewlyShipped && reduceMotion ? 0 : shippedOpacity
                )
                .opacity(softFade ? 0.3 : 1)

                // The count takes the summary's place, so nothing moves.
                ZStack(alignment: .topLeading) {

                    Text(isAwaited ? previousSummary : summary)
                        .opacity(isPlaying ? 0 : 1)
                        .id(isAwaited ? .inProgress : stage)
                        .transition(reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .offset(y: RawdeaSpacing.sm).combined(with: .opacity),
                                removal: .identity
                            ))

                    if isPlaying {
                        Text("\(landed) of \(dots.count == 1 ? "1 post" : "\(dots.count) posts")")
                            .monospacedDigit()
                            .accessibilityHidden(true)
                    }
                }
                .font(RawdeaTypography.metadata)
                .foregroundStyle(RawdeaPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .animation(
                    reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.45),
                    value: isAwaited ? .inProgress : stage
                )
            }
        }
        .overlayPreferenceValue(RawdeaEarlyBarKey.self) { anchor in
            if isPlaying, let anchor {
                GeometryReader { proxy in
                    rain(into: proxy[anchor])
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .overlayPreferenceValue(RawdeaStageBarsKey.self) { bars in
            if let shipping, let from = bars[1], let to = bars[2] {
                GeometryReader { proxy in
                    RawdeaShippedDots(
                        arrival: shipping.arrival,
                        startedAt: shipping.startedAt,
                        from: proxy[from],
                        to: proxy[to]
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onAppear { shownStage = stage }
        // Leaving mid-play settles on the finished line.
        .onDisappear {
            shipping = nil
            isFading = false
            shippedOpacity = 1
            shownStage = stage
        }
        .onChange(of: summary) { old, _ in previousSummary = old }
        .onChange(of: stage) { old, new in
            beginShipping(from: old, to: new)
        }
        .task(id: shipping?.id) {
            await runShipping()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .sensoryFeedback(.success, trigger: shippedSuccess)
        .sensoryFeedback(.impact(weight: .light), trigger: landed) { _, new in
            new > 0 && new < dots.count
        }
        .sensoryFeedback(.success, trigger: finished)
        .task(id: arrivalCount) {
            await play()
        }
    }

    private func beginShipping(from old: ProjectStage, to new: ProjectStage) {

        shipping = nil
        isFading = false
        shippedOpacity = 1

        switch ShippedArrival.change(from: old, to: new, reduceMotion: reduceMotion) {
        case .none:
            shownStage = new
        case .fade:
            shownStage = new
            isFading = true
            shippedOpacity = 0
            // On the next turn, so the fade has somewhere to start.
            Task {
                withAnimation(.easeInOut(duration: 0.2)) { shippedOpacity = 1 }
                try? await Task.sleep(for: .seconds(ShippedArrival.fade))
                isFading = false
            }
        case .play:
            shownStage = old
            shipping = Shipping(
                arrival: ShippedArrival(count: postCount),
                startedAt: Date()
            )
        }
    }

    private func runShipping() async {

        guard let shipping else { return }
        let arrival = shipping.arrival

        func wait(until time: Double) async -> Bool {
            let seconds = time - Date().timeIntervalSince(shipping.startedAt)
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            return !Task.isCancelled
        }

        for time in arrival.hapticTimes {
            guard await wait(until: time) else { return }
            taps += 1
        }
        guard await wait(until: arrival.arrived) else { return }
        if !arrival.arcs.isEmpty { shippedSuccess += 1 }

        guard await wait(until: arrival.end) else { return }
        shownStage = .shipped
        self.shipping = nil
    }

    /// Room around the bar for dots to start in.
    private static let reach: CGFloat = 80

    private func rain(into bar: CGRect) -> some View {

        GeometryReader { proxy in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    draw(
                        in: &context,
                        size: size,
                        bar: bar.offsetBy(dx: 0, dy: Self.reach),
                        elapsed: timeline.date.timeIntervalSince(startedAt)
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height + Self.reach * 2)
            .offset(y: -Self.reach)
        }
    }

    private func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        bar: CGRect,
        elapsed: Double
    ) {
        let ease = UnitCurve.bezier(
            startControlPoint: UnitPoint(x: 0.55, y: 0),
            endControlPoint: UnitPoint(x: 0.9, y: 0.55)
        )
        let radius = 3.5

        for (index, dot) in dots.enumerated() {
            let time = (elapsed - EarlyArrival.start(of: index, count: dots.count))
                / EarlyArrival.fall
            guard time > 0, time < 1 else { continue }

            let progress = ease.value(at: time)
            let target = CGPoint(
                x: bar.minX + bar.width * dot.position + dot.jitter,
                y: bar.midY
            )
            let start = CGPoint(
                x: min(max(target.x + dot.offset.width, radius), size.width - radius),
                y: min(max(target.y + dot.offset.height, radius), size.height - radius)
            )
            // Fades in, shrinks on the way, and vanishes into the bar.
            let travel = min(progress / 0.94, 1)
            let scale = progress < 0.94
                ? 1 - 0.65 * travel
                : 0.35 - 0.25 * (progress - 0.94) / 0.06
            let opacity = progress < 0.12
                ? progress / 0.12
                : progress > 0.94 ? (1 - progress) / 0.06 : 1
            let center = CGPoint(
                x: start.x + (target.x - start.x) * travel,
                y: start.y + (target.y - start.y) * travel
            )
            let side = radius * 2 * scale

            context.opacity = opacity
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - side / 2,
                    y: center.y - side / 2,
                    width: side,
                    height: side
                )),
                with: .color(RawdeaPalette.accent)
            )
        }
    }

    private static func makeDots(count: Int) -> [Dot] {
        // Evenly spread angles, taken in random order.
        let angles = (0..<count).map {
            Double($0) * 360 / Double(count) + .random(in: -12...12)
        }
        .shuffled()

        return angles.enumerated().map { index, degrees in
            let radians = degrees * .pi / 180
            return Dot(
                position: (Double(index) + 0.5) / Double(count),
                jitter: .random(in: -3...3),
                offset: CGSize(
                    width: cos(radians) * .random(in: 70...120),
                    height: sin(radians) * .random(in: 45...80)
                )
            )
        }
    }

    private func play() async {

        guard let count = arrivalCount, count > 0 else { return }

        if reduceMotion {
            softFade = true
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(.easeInOut(duration: 0.2)) { softFade = false }
            onArrivalEnd()
            return
        }

        defer {
            dots = []
            landed = 0
        }

        landed = 0
        startedAt = Date()
        dots = Self.makeDots(count: count)

        for index in 0..<count {
            let due = EarlyArrival.start(of: index, count: count) + EarlyArrival.fall
            let wait = due - Date().timeIntervalSince(startedAt)
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            landed = index + 1
            pulse += 1
        }

        finished += 1
        // Let the last pulse and the full count be seen.
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled else { return }
        onArrivalEnd()
    }
}

/// Where the Early segment sits, for the dots to aim at.
struct RawdeaEarlyBarKey: PreferenceKey {

    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}
