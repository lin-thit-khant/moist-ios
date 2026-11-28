//
//  ShippedArrival.swift
//  Rawdea
//

import Foundation

/// The one play when a Project ships: a dot per post arcs from the
/// In progress bar to the Shipped bar, then the three bars join.
/// Times are in seconds from the stage change.
nonisolated struct ShippedArrival {

    static let flight = 0.65
    static let fade = 0.25
    /// From the last landing to the first bridge.
    static let beforeBridges = 0.35
    static let bridgeStagger = 0.3
    static let bridge = 0.52
    static let pulse = 0.9
    static let mostHaptics = 8

    struct Arc {
        let start: Double
        let duration: Double
        /// Above the bars when negative, below when positive.
        let peakOffset: Double
        /// How far along the way the peak sits.
        let peakPosition: Double
        /// When, within the flight, the peak is reached.
        let peakTime: Double
        let peakScale: Double

        var landing: Double { start + duration }
    }

    let arcs: [Arc]

    init(count: Int) {
        var generator = SystemRandomNumberGenerator()
        self.init(count: count, using: &generator)
    }

    init(count: Int, using generator: inout some RandomNumberGenerator) {
        let gap = Self.gap(count: count)
        arcs = (0..<max(count, 0)).map { index in
            Arc(
                start: Double(index) * gap,
                duration: Self.flight * .random(in: 0.85...1.25, using: &generator),
                peakOffset: .random(in: 10...46, using: &generator)
                    * (Bool.random(using: &generator) ? 1 : -1),
                peakPosition: .random(in: 0.35...0.65, using: &generator),
                peakTime: .random(in: 0.4...0.6, using: &generator),
                peakScale: .random(in: 1.1...1.5, using: &generator)
            )
        }
    }

    static func gap(count: Int) -> Double {
        min(0.11, 2.4 / Double(max(count, 1)))
    }

    /// What a stage change on screen does. Opening a shipped Project
    /// is not a change, so it never plays again.
    enum Change {
        case none
        /// Reduce Motion: one soft fade, no dots or bridges.
        case fade
        case play
    }

    static func change(
        from old: ProjectStage,
        to new: ProjectStage,
        reduceMotion: Bool
    ) -> Change {
        guard new == .shipped, old != .shipped else { return .none }
        return reduceMotion ? .fade : .play
    }

    // MARK: - Sequence

    /// The Shipped bar starts filling as the first dot lands.
    var sweepStart: Double { arcs.isEmpty ? 0 : 0.8 * Self.flight }

    var sweepDuration: Double {
        max(0.9, (arcs.map(\.landing).max() ?? 0) - 0.4 * Self.flight)
    }

    /// The last landing, or the end of the sweep with no posts.
    var arrived: Double {
        arcs.map(\.landing).max() ?? sweepDuration
    }

    func bridgeStart(_ index: Int) -> Double {
        arrived + Self.beforeBridges + Double(index) * Self.bridgeStagger
    }

    var pulseStart: Double { bridgeStart(1) + Self.bridge }

    var end: Double { pulseStart + Self.pulse }

    /// Landings that tap lightly: a few, spread evenly. The last
    /// landing is left for the success haptic.
    var hapticTimes: [Double] {
        let landings = arcs.map(\.landing).sorted().dropLast()
        let taps = min(landings.count, Self.mostHaptics)
        return (0..<taps).map { landings[$0 * landings.count / taps] }
    }

    // MARK: - Frame

    /// How the track looks at one moment.
    struct Frame: Equatable {
        /// The crimson on the Shipped bar, from its leading edge.
        var shippedFill = 1.0
        /// The crimson over the In progress bar.
        var inProgressFill = 1.0
        /// Each bridge's progress, 0 to 1 (it overshoots a little).
        var bridges = [1.0, 1.0]
        var glow = 0.0
        /// The names and summary now read Shipped.
        var hasArrived = true

        /// A shipped Project at rest: one still crimson line.
        static let rest = Frame()

        static let start = Frame(
            shippedFill: 0,
            inProgressFill: 0,
            bridges: [0, 0],
            glow: 0,
            hasArrived: false
        )
    }

    func frame(at time: Double) -> Frame {
        func progress(from start: Double, over duration: Double) -> Double {
            min(max((time - start) / duration, 0), 1)
        }

        guard time < end else { return .rest }

        let beat = progress(from: pulseStart, over: Self.pulse)

        return Frame(
            shippedFill: progress(from: sweepStart, over: sweepDuration),
            inProgressFill: progress(from: arrived, over: Self.fade),
            bridges: [0, 1].map {
                progress(from: bridgeStart($0), over: Self.bridge)
            },
            glow: (1 - cos(beat * 2 * .pi)) / 2,
            hasArrived: time >= arrived
        )
    }

    /// A bridge's width and thickness from its eased progress: it
    /// closes the gap while swelling, then settles to the bar.
    static func bridgeShape(at eased: Double) -> (width: Double, thickness: Double) {
        eased < 0.55
            ? (max(eased / 0.55, 0), 1 + 1.6 * max(eased / 0.55, 0))
            : (1, 2.6 - 1.6 * (eased - 0.55) / 0.45)
    }
}
