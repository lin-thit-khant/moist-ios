//
//  ProjectCycle.swift
//  Rawdea
//

import Foundation

enum ProjectCycle {

    static let nameLimit = 60

    /// "Cycle 2" or "Cycle 2: Winter glazes".
    static func title(_ number: Int, name: String?) -> String {
        guard let name, !name.isEmpty else { return "Cycle \(number)" }
        return "Cycle \(number): \(name)"
    }
}

/// Which cycles the Timeline shows.
enum CycleChoice: Hashable {
    case all
    case current
    case past(Int)

    /// Newest first.
    func numbers(current: Int) -> [Int] {
        switch self {
        case .all: Array((1...max(current, 1)).reversed())
        case .current: [current]
        case .past(let number): [number]
        }
    }

    func title(current: Int) -> String {
        switch self {
        case .all: "All"
        case .current: "Cycle \(current)"
        case .past(let number): "Cycle \(number)"
        }
    }
}

/// What a finished cycle amounted to.
struct CycleRecap: Identifiable {

    let number: Int
    let startedAt: Date
    let shippedAt: Date?
    let postCount: Int
    /// Newest first.
    let moves: [ProjectStageEvent]
    let decisions: [Post]

    var id: Int { number }

    /// Built from what the viewer can read.
    init(
        number: Int,
        projectStartedAt: Date,
        posts: [Post],
        events: [ProjectStageEvent]
    ) {
        let cyclePosts = posts.filter { $0.cycleNumber == number }
        let cycleEvents = events.filter { $0.cycleNumber == number }

        self.number = number
        startedAt = cycleEvents.first { $0.startsCycle == true }?.createdAt
            ?? projectStartedAt
        shippedAt = cycleEvents
            .filter { $0.toStage == .shipped }
            .map(\.createdAt)
            .max()
        postCount = cyclePosts.count
        moves = cycleEvents
            .filter { $0.startsCycle != true }
            .sorted { $0.createdAt > $1.createdAt }
        decisions = cyclePosts
            .filter { $0.kind == .decision }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
