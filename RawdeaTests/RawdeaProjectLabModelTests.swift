//
//  RawdeaProjectLabModelTests.swift
//  Rawdea
//

import XCTest
@testable import Rawdea

@MainActor
final class RawdeaProjectLabModelTests: XCTestCase {

    private let projectId = UUID()

    private func date(_ day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400))
    }

    private func post(_ day: Int, kind: PostKind = .note) -> Post {
        Post(
            id: UUID(), userId: UUID(), content: "Day \(day)",
            createdAt: date(day), kind: kind
        )
    }

    private func project(stage: ProjectStage, movedOn day: Int) -> Project {
        Project(
            id: projectId, userId: UUID(), name: "Lab", createdAt: date(1),
            isArchived: false, isHidden: false, isPinned: false,
            stage: stage, stageChangedAt: date(day), isDefault: false
        )
    }

    func testAnnouncingPostBelongsToTheNewStage() {

        let old = post(2)
        let announcement = post(4, kind: .progress)
        let later = post(6)
        let event = ProjectStageEvent(
            id: UUID(), projectId: projectId, fromStage: .early,
            toStage: .inProgress, postId: announcement.id,
            createdAt: date(5)
        )

        let groups = ProjectTimeline.groups(
            posts: [later, announcement, old],
            events: [event],
            currentStage: .inProgress
        )

        XCTAssertEqual(groups.map(\.stage), [.inProgress, .early])
        XCTAssertEqual(
            groups.first?.items.map(\.id),
            [later.id, announcement.id, event.id]
        )
        XCTAssertEqual(groups.last?.items.map(\.id), [old.id])
    }

    func testTimelineWithoutHistoryIsOneGroup() {

        let groups = ProjectTimeline.groups(
            posts: [post(3), post(2)], events: [], currentStage: .shipped
        )

        XCTAssertEqual(groups.map(\.stage), [.shipped])
        XCTAssertTrue(
            ProjectTimeline.groups(posts: [], events: [], currentStage: .early)
                .isEmpty
        )
    }

    func testFollowedRowCountsOnlyWhatIsNew() {

        let row = FollowedProjectRow(
            project: project(stage: .inProgress, movedOn: 5),
            posts: [post(4, kind: .decision), post(2)],
            lastSeen: date(3)
        )

        XCTAssertEqual(row.newCount, 2)
        XCTAssertEqual(row.summary, "Moved to In progress")

        let seen = FollowedProjectRow(
            project: project(stage: .early, movedOn: 1),
            posts: [post(4, kind: .question)],
            lastSeen: date(9)
        )

        XCTAssertEqual(seen.newCount, 0)
        XCTAssertEqual(seen.summary, "Question: Day 4")
    }

    func testFollowedRowCapsTheNewCount() {

        let row = FollowedProjectRow(
            project: project(stage: .early, movedOn: 1),
            posts: (2...11).map { post($0) },
            lastSeen: nil
        )

        XCTAssertEqual(row.newCountText, "9+")
    }
}
