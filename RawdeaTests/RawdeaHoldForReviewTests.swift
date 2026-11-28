//
//  RawdeaHoldForReviewTests.swift
//  Rawdea
//
//  The server rules are tested in supabase/tests/hold_for_review.sql.
//

import XCTest
@testable import Rawdea

final class RawdeaHoldForReviewTests: XCTestCase {

    private struct ServerError: LocalizedError {
        let errorDescription: String?
    }

    func testHoldReasonIsReadFromTheServerError() {
        for reason in [HoldReason.possibleInsult, .severalLinks, .newAccountLink] {
            let error = ServerError(
                errorDescription: "RAWDEA_FILTER_HELD:\(reason.rawValue)"
            )
            XCTAssertEqual(HoldReason.from(error), reason)
        }

        for other in [
            "RAWDEA_FILTER_BLOCKED:excessive_links",
            "RAWDEA_FILTER_HELD_EDIT:several_links",
            "RAWDEA_RATE_LIMIT"
        ] {
            XCTAssertNil(HoldReason.from(ServerError(errorDescription: other)), other)
        }
    }

    func testRateLimitAndHeldEditHavePlainMessages() {
        XCTAssertTrue(
            PublicationErrorMessage.from(ServerError(errorDescription: "RAWDEA_RATE_LIMIT"))
                .contains("3 times an hour")
        )
        XCTAssertTrue(
            PublicationErrorMessage.from(
                ServerError(errorDescription: "RAWDEA_FILTER_HELD_EDIT:possible_insult")
            ).contains("wasn't saved")
        )
    }

    func testNoticeWordingAndSecondLook() {
        let approved = notice(.approved)
        XCTAssertEqual(approved.title, "Your post is live")
        XCTAssertFalse(approved.canAskAgain)

        let removed = notice(.removed)
        XCTAssertEqual(removed.title, "Your post was removed")
        XCTAssertEqual(
            removed.message,
            "It broke the rule: Several links in one post. You can ask for a second look."
        )
        XCTAssertTrue(removed.canAskAgain)

        let asked = notice(.pending, appealed: true)
        XCTAssertTrue(asked.isSecondLookRequested)
        XCTAssertFalse(asked.canAskAgain)

        let final = notice(.removed, appealed: true)
        XCTAssertFalse(final.canAskAgain)
        XCTAssertFalse(final.message.contains("ask"))
    }

    func testAccountAge() {
        let now = Date()
        func age(_ days: Double) -> String {
            HeldQueueItem(
                id: UUID(), content: "", reason: .severalLinks, username: "a",
                accountCreatedAt: now.addingTimeInterval(-days * 86_400),
                appealed: false
            ).accountAge(at: now)
        }
        XCTAssertEqual(age(0.5), "New today")
        XCTAssertEqual(age(1.5), "1 day old")
        XCTAssertEqual(age(30), "30 days old")
    }

    private func notice(
        _ status: HeldPostNotice.Status,
        appealed: Bool = false
    ) -> HeldPostNotice {
        HeldPostNotice(
            id: UUID(), content: "a.com b.com", reason: .severalLinks,
            status: status, appealed: appealed, seen: false
        )
    }
}
