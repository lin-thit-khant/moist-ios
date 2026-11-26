//
//  RawdeaPostAgeTests.swift
//  Rawdea
//

import XCTest
@testable import Rawdea

final class RawdeaPostAgeTests: XCTestCase {

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testJustPublishedPostReadsNow() {
        XCTAssertEqual(PostRowView.relativeAge(of: now, at: now), "now")
    }

    func testServerClockAheadOfDeviceReadsNow() {
        let slightlyInFuture = now.addingTimeInterval(5)
        XCTAssertEqual(PostRowView.relativeAge(of: slightlyInFuture, at: now), "now")
    }

    func testOlderPostUsesRelativeTime() {
        let twoHoursAgo = now.addingTimeInterval(-2 * 60 * 60)
        let age = PostRowView.relativeAge(of: twoHoursAgo, at: now)
        XCTAssertNotEqual(age, "now")
        XCTAssertTrue(age.contains("2"), "Expected a two-hour age, got \(age)")
    }
}
