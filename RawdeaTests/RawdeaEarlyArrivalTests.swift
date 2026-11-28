import XCTest
@testable import Rawdea

final class RawdeaEarlyArrivalTests: XCTestCase {

    func testFewPostsKeepTheLongGap() {
        XCTAssertEqual(EarlyArrival.gap(count: 1), 0.43)
        XCTAssertEqual(EarlyArrival.gap(count: 8), 0.43)
        XCTAssertEqual(EarlyArrival.gap(count: 50), 0.072, accuracy: 0.0001)
    }

    func testPlaybackStaysUnderFiveSecondsForAnyCount() {
        for count in [1, 8, 9, 50, 500] {
            let end = EarlyArrival.start(of: count - 1, count: count) + EarlyArrival.fall
            XCTAssertLessThan(end, 4.7, "\(count) posts")
        }
    }

    func testPlaysOnlyOnceForAFollowerOfAnEarlyProjectWithPosts() {
        func plays(
            _ stage: ProjectStage = .early,
            follower: Bool = true,
            posts: Int = 3,
            seen: Bool = false
        ) -> Bool {
            EarlyArrival.shouldPlay(
                stage: stage, isFollower: follower, postCount: posts, wasSeen: seen
            )
        }

        XCTAssertTrue(plays())
        XCTAssertFalse(plays(.inProgress))
        XCTAssertFalse(plays(.shipped))
        XCTAssertFalse(plays(follower: false))
        XCTAssertFalse(plays(posts: 0))
        XCTAssertFalse(plays(seen: true))
    }

    func testSeenKeyIsPerViewerAndProject() {
        let viewer = UUID(), other = UUID(), project = UUID()
        XCTAssertNotEqual(
            EarlyArrival.seenKey(viewerId: viewer, projectId: project),
            EarlyArrival.seenKey(viewerId: other, projectId: project)
        )
    }
}
