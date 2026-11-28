//
//  EarlyArrival.swift
//  Rawdea
//

import Foundation

/// The one-time arrival of an Early Project's posts: one dot per
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

    /// It plays once, for a follower of a Project that is still Early.
    static func shouldPlay(
        stage: ProjectStage,
        isFollower: Bool,
        postCount: Int,
        wasSeen: Bool
    ) -> Bool {
        stage == .early && isFollower && postCount > 0 && !wasSeen
    }

    /// Remembered on this device, per viewer and Project.
    static func seenKey(viewerId: UUID, projectId: UUID) -> String {
        "rawdea.earlyArrival.\(viewerId.uuidString).\(projectId.uuidString)"
    }
}
