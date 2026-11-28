//
//  EarlyArrival.swift
//  Rawdea
//

import Foundation

/// The arrival of an Early Project's posts: one dot per
/// post, falling into the Early bar one after another.
enum EarlyArrival {

    static let lead = 0.3
    static let fall = 0.72

    /// Longer waits for a few posts; many arrive as a quick rain,
    /// so every dot has started within 3.6 seconds.
    static func gap(count: Int) -> Double {
        min(0.43, 3.6 / Double(max(count, 1)))
    }

    /// Seconds after the start at which dot `index` begins to fall.
    static func start(of index: Int, count: Int) -> Double {
        lead + Double(index) * gap(count: count)
    }

    /// It plays each time a Project that is still Early is opened.
    static func shouldPlay(stage: ProjectStage, postCount: Int) -> Bool {
        stage == .early && postCount > 0
    }
}
