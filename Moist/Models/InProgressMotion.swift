//
//  InProgressMotion.swift
//  Rawdea
//

import Foundation

/// The In progress segment's life: a breathing glow, and one dot per
/// post riding a wave that winds around the bar without travelling.
nonisolated enum InProgressMotion {

    enum Style: Equatable {
        case off
        /// Reduce Motion: a faint outline and glow that never move.
        case still
        case live
    }

    static let breath = 2.8
    static let wave = 2.6
    static let wavelength = 84.0
    static let amplitude = 7.0
    static let dotSize = 6.0
    /// The sweep to a new stage finishes first.
    static let sweep = 0.7

    static func style(
        stage: ProjectStage,
        reduceMotion: Bool,
        isVisible: Bool
    ) -> Style {
        guard stage == .inProgress, isVisible else { return .off }
        return reduceMotion ? .still : .live
    }

    /// 0 at rest, 1 at the brightest point of a breath.
    static func glow(at time: Double) -> Double {
        (1 - cos(time / breath * 2 * .pi)) / 2
    }

    struct Dot: Equatable {
        let x: Double
        /// Distance below the middle of the bar.
        let offset: Double
        /// Towards the viewer when positive, behind the bar when not.
        let depth: Double

        var isInFront: Bool { depth > 0 }
        var scale: Double { 1 + 0.3 * depth }
    }

    /// Exactly one dot per post, spread evenly along the bar.
    static func dots(count: Int, width: Double, time: Double) -> [Dot] {
        (0..<max(count, 0)).map { index in
            let x = (Double(index) + 0.5) / Double(count) * width
            let angle = (x / wavelength - time / wave) * 2 * .pi
            return Dot(x: x, offset: amplitude * sin(angle), depth: cos(angle))
        }
    }
}
