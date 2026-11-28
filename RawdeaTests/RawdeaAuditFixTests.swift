//
//  RawdeaAuditFixTests.swift
//  Rawdea
//

import XCTest
@testable import Rawdea

final class RawdeaAuditFixTests: XCTestCase {

    func testHiddenBestAnswerReadsAsOpen() {
        let best = UUID()

        XCTAssertNil(PostDetailViewModel.shownBestReply(nil, loaded: [best], hasMore: false))
        XCTAssertNil(PostDetailViewModel.shownBestReply(best, loaded: [], hasMore: false))
        XCTAssertEqual(PostDetailViewModel.shownBestReply(best, loaded: [best], hasMore: false), best)
        // It may be on a page that has not loaded.
        XCTAssertEqual(PostDetailViewModel.shownBestReply(best, loaded: [], hasMore: true), best)
    }

    func testUsernameRuleMatchesDatabase() {
        for valid in ["abc", "user_75f828b64211", String(repeating: "a", count: 24)] {
            XCTAssertTrue(Profile.isValidUsername(valid), valid)
        }
        for invalid in ["ab", "Abc", "a b c", "abc!", "abc\n", String(repeating: "a", count: 25)] {
            XCTAssertFalse(Profile.isValidUsername(invalid), invalid)
        }
    }
}
