import XCTest
@testable import Rawdea

final class RawdeaShippedArrivalTests: XCTestCase {

    private struct Seeded: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func arrival(_ count: Int, seed: UInt64 = 7) -> ShippedArrival {
        var generator = Seeded(state: seed)
        return ShippedArrival(count: count, using: &generator)
    }

    func testOneDotPerPost() {
        for count in [0, 1, 8, 50, 200] {
            XCTAssertEqual(arrival(count).arcs.count, count)
        }
    }

    func testEachArcStaysInRangeAndDiffers() {
        let arcs = arrival(200).arcs

        for arc in arcs {
            XCTAssertTrue((10...46).contains(abs(arc.peakOffset)))
            XCTAssertTrue((0.35...0.65).contains(arc.peakPosition))
            XCTAssertTrue((1.1...1.5).contains(arc.peakScale))
            XCTAssertTrue((0.65 * 0.85...0.65 * 1.25).contains(arc.duration))
        }
        XCTAssertTrue(arcs.contains { $0.peakOffset < 0 })
        XCTAssertTrue(arcs.contains { $0.peakOffset > 0 })
        XCTAssertGreaterThan(Set(arcs.map(\.duration)).count, 100)
    }

    func testDotsLeaveCloserTogetherWhenThereAreMany() {
        XCTAssertEqual(ShippedArrival.gap(count: 8), 0.11)
        XCTAssertEqual(ShippedArrival.gap(count: 50), 0.048, accuracy: 0.0001)
        XCTAssertEqual(arrival(8).arcs[3].start, 0.33, accuracy: 0.0001)
    }

    func testStepsHappenInOrder() {
        for count in [0, 1, 8, 50] {
            let play = arrival(count)

            XCTAssertLessThan(play.sweepStart, play.arrived + 0.001, "\(count)")
            XCTAssertGreaterThan(play.bridgeStart(0), play.arrived)
            XCTAssertEqual(play.bridgeStart(1) - play.bridgeStart(0), 0.3, accuracy: 0.0001)
            XCTAssertEqual(play.pulseStart, play.bridgeStart(1) + 0.52, accuracy: 0.0001)
            // The Shipped bar is full before the second gap closes.
            XCTAssertLessThanOrEqual(play.sweepStart + play.sweepDuration, play.pulseStart)
        }
    }

    func testFramesRunFromEmptyToOneStillLine() {
        let play = arrival(8)

        XCTAssertEqual(play.frame(at: 0), .start)

        let landed = play.frame(at: play.arrived + 0.3)
        XCTAssertTrue(landed.hasArrived)
        XCTAssertEqual(landed.inProgressFill, 1)
        XCTAssertEqual(landed.bridges, [0, 0])

        XCTAssertEqual(play.frame(at: play.pulseStart + 0.45).glow, 1, accuracy: 0.0001)
        XCTAssertEqual(play.frame(at: play.end + 5), .rest)
        XCTAssertEqual(ShippedArrival.Frame.rest.glow, 0)
    }

    func testHapticsAreCappedAndLeaveTheLastLanding() {
        XCTAssertEqual(arrival(0).hapticTimes.count, 0)
        XCTAssertEqual(arrival(1).hapticTimes.count, 0)
        XCTAssertEqual(arrival(5).hapticTimes.count, 4)

        let many = arrival(50)
        XCTAssertEqual(many.hapticTimes.count, 8)
        XCTAssertLessThan(many.hapticTimes.max() ?? 0, many.arrived)
    }

    func testBridgeClosesThenSettles() {
        XCTAssertEqual(ShippedArrival.bridgeShape(at: 0).width, 0)
        XCTAssertEqual(ShippedArrival.bridgeShape(at: 0.55).thickness, 2.6, accuracy: 0.0001)
        XCTAssertEqual(ShippedArrival.bridgeShape(at: 1).width, 1)
        XCTAssertEqual(ShippedArrival.bridgeShape(at: 1).thickness, 1, accuracy: 0.0001)
    }

    func testPlaysOnlyOnAChangeToShippedAndReducedMotionFades() {
        func play(
            _ old: ProjectStage, _ new: ProjectStage, reduce: Bool = false
        ) -> ShippedArrival.Change {
            ShippedArrival.change(from: old, to: new, reduceMotion: reduce)
        }

        XCTAssertEqual(play(.inProgress, .shipped), .play)
        XCTAssertEqual(play(.early, .shipped), .play)
        XCTAssertEqual(play(.inProgress, .shipped, reduce: true), .fade)
        XCTAssertEqual(play(.shipped, .shipped), .none)
        XCTAssertEqual(play(.shipped, .inProgress), .none)
        XCTAssertEqual(play(.early, .inProgress, reduce: true), .none)
    }
}
