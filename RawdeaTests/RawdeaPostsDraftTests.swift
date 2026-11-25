//
//  RawdeaPostsDraftTests.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 25/11/2569 BE.
//

import XCTest
@testable import Rawdea

final class RawdeaPostDraftTests: XCTestCase {

    func testEmptyPostIsInvalid() {

        let draft = RawdeaPostDraft(
            content: ""
        )

        XCTAssertTrue(draft.isEmpty)
        XCTAssertFalse(draft.isValid)
    }

    func testWhitespaceOnlyPostIsInvalid() {

        let draft = RawdeaPostDraft(
            content: "   \n\t   "
        )

        XCTAssertTrue(draft.isEmpty)
        XCTAssertFalse(draft.isValid)
    }

    func testShortPostIsValid() {

        let draft = RawdeaPostDraft(
            content: "An unfinished idea."
        )

        XCTAssertTrue(draft.isValid)
        XCTAssertFalse(draft.isOverLimit)
    }

    func testExactly500CharactersAreAccepted() {

        let draft = RawdeaPostDraft(
            content: String(
                repeating: "a",
                count: 500
            )
        )

        XCTAssertEqual(draft.characterCount, 500)
        XCTAssertEqual(draft.remainingCharacters, 0)
        XCTAssertTrue(draft.isValid)
    }

    func test501CharactersAreRejected() {

        let draft = RawdeaPostDraft(
            content: String(
                repeating: "a",
                count: 501
            )
        )

        XCTAssertEqual(draft.characterCount, 501)
        XCTAssertEqual(draft.remainingCharacters, -1)
        XCTAssertTrue(draft.isOverLimit)
        XCTAssertFalse(draft.isValid)
    }

    func testWhitespaceIsTrimmedForPublication() {

        let draft = RawdeaPostDraft(
            content: "  A thought. \n"
        )

        XCTAssertEqual(
            draft.trimmedContent,
            "A thought."
        )
    }

    func testUnchangedPostHasNoUnsavedChanges() {

        let draft = RawdeaPostDraft(
            content: "Original"
        )

        XCTAssertFalse(
            draft.hasUnsavedChanges(
                comparedTo: "Original"
            )
        )
    }

    func testWhitespaceEditsAreProtected() {

        let draft = RawdeaPostDraft(
            content: "Original "
        )

        XCTAssertTrue(
            draft.hasUnsavedChanges(
                comparedTo: "Original"
            )
        )

        XCTAssertFalse(
            draft.hasSubmittableChanges(
                comparedTo: "Original"
            )
        )
    }

    func testChangedContentCanBeSaved() {

        let draft = RawdeaPostDraft(
            content: "Updated thought."
        )

        XCTAssertTrue(
            draft.hasSubmittableChanges(
                comparedTo: "Original"
            )
        )
    }

    func testOverLimitEditsCannotBeSaved() {

        let draft = RawdeaPostDraft(
            content: String(
                repeating: "a",
                count: 501
            )
        )

        XCTAssertFalse(
            draft.hasSubmittableChanges(
                comparedTo: "Original"
            )
        )
    }
    
    func testFamilyEmojiMatchesDatabaseLength() {

        let draft = RawdeaPostDraft(
            content: "👨‍👩‍👧‍👦"
        )

        XCTAssertEqual(draft.characterCount, 7)
        XCTAssertEqual(draft.remainingCharacters, 493)
        XCTAssertTrue(draft.isValid)
    }

    func testUnicodeExactlyAtDatabaseLimit() {

        let draft = RawdeaPostDraft(
            content: String(
                repeating: "🇲🇲",
                count: 250
            )
        )

        XCTAssertEqual(draft.characterCount, 500)
        XCTAssertEqual(draft.remainingCharacters, 0)
        XCTAssertTrue(draft.isValid)
    }

    func testUnicodeOverDatabaseLimit() {

        let draft = RawdeaPostDraft(
            content: String(
                repeating: "🇲🇲",
                count: 250
            ) + "a"
        )

        XCTAssertEqual(draft.characterCount, 501)
        XCTAssertEqual(draft.remainingCharacters, -1)
        XCTAssertTrue(draft.isOverLimit)
        XCTAssertFalse(draft.isValid)
    }

    func testBurmeseCombiningCharacters() {

        let text = "\u{1000}\u{103A}"

        XCTAssertEqual(
            RawdeaTextLength.count(text),
            2
        )
    }

    func testCombiningAccentMatchesDatabaseLength() {

        let composed = "\u{00E9}"

        let decomposed = "e\u{0301}"

        XCTAssertEqual(
            RawdeaTextLength.count(composed),
            1
        )

        XCTAssertEqual(
            RawdeaTextLength.count(decomposed),
            2
        )
    }

}
