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

    func testPlaysForAnyEarlyProjectWithPosts() {
        XCTAssertTrue(EarlyArrival.shouldPlay(stage: .early, postCount: 3))
        XCTAssertFalse(EarlyArrival.shouldPlay(stage: .inProgress, postCount: 3))
        XCTAssertFalse(EarlyArrival.shouldPlay(stage: .shipped, postCount: 3))
        XCTAssertFalse(EarlyArrival.shouldPlay(stage: .early, postCount: 0))
    }
}
