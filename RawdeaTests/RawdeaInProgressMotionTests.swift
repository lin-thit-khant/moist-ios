import XCTest
@testable import Rawdea

final class RawdeaInProgressMotionTests: XCTestCase {

    func testOneDotPerPostSpreadAlongTheBar() {
        for count in [0, 1, 8, 50] {
            XCTAssertEqual(InProgressMotion.dots(count: count, width: 100, time: 0).count, count)
        }
        XCTAssertEqual(
            InProgressMotion.dots(count: 4, width: 100, time: 1.3).map(\.x),
            [12.5, 37.5, 62.5, 87.5]
        )
    }

    func testDotsStayNearTheBarAndDoNotTravel() {
        let first = InProgressMotion.dots(count: 50, width: 120, time: 0)
        let later = InProgressMotion.dots(count: 50, width: 120, time: 0.9)

        XCTAssertEqual(first.map(\.x), later.map(\.x))
        XCTAssertNotEqual(first.map(\.offset), later.map(\.offset))
        XCTAssertTrue(later.allSatisfy { abs($0.offset) <= 7 })
    }

    func testOneWaveCycleRepeats() {
        let start = InProgressMotion.dots(count: 8, width: 120, time: 0.4)
        let next = InProgressMotion.dots(count: 8, width: 120, time: 0.4 + 2.6)

        for (a, b) in zip(start, next) {
            XCTAssertEqual(a.offset, b.offset, accuracy: 0.0001)
        }
    }

    func testDepthOrdersFrontAndBehind() {
        // x = 42 is half a wavelength after x = 0, on the far side.
        let near = InProgressMotion.dots(count: 1, width: 0, time: 0)[0]
        let far = InProgressMotion.dots(count: 1, width: 84, time: 0)[0]

        XCTAssertTrue(near.isInFront)
        XCTAssertEqual(near.scale, 1.3, accuracy: 0.0001)
        XCTAssertFalse(far.isInFront)
        XCTAssertEqual(far.scale, 0.7, accuracy: 0.0001)
        // Behind, it is small enough for the 5 pt bar to hide it.
        XCTAssertLessThan(InProgressMotion.dotSize * far.scale, 5)
    }

    func testBreathStartsAtRestAndPeaksHalfway() {
        XCTAssertEqual(InProgressMotion.glow(at: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(InProgressMotion.glow(at: 1.4), 1, accuracy: 0.0001)
        XCTAssertEqual(InProgressMotion.glow(at: 2.8), 0, accuracy: 0.0001)
    }

    func testMovesOnlyWhenVisibleInProgressAndStillUnderReduceMotion() {
        func style(
            _ stage: ProjectStage = .inProgress,
            reduce: Bool = false,
            visible: Bool = true
        ) -> InProgressMotion.Style {
            InProgressMotion.style(stage: stage, reduceMotion: reduce, isVisible: visible)
        }

        XCTAssertEqual(style(), .live)
        XCTAssertEqual(style(reduce: true), .still)
        XCTAssertEqual(style(visible: false), .off)
        XCTAssertEqual(style(.early), .off)
        XCTAssertEqual(style(.shipped, reduce: true), .off)
    }
}
