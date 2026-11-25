//
//  RawdeaAuthCallbackRouteTests.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 25/11/2569 BE.
//

import Foundation
import XCTest
@testable import Rawdea

final class RawdeaAuthCallbackRouteTests: XCTestCase {

    func testRawdeaLoginCallback() throws {

        let url = try XCTUnwrap(
            URL(
                string: "rawdea://login-callback"
            )
        )

        XCTAssertEqual(
            RawdeaAuthCallbackRoute(url: url),
            .login
        )
    }

    func testLegacyLoginCallback() throws {

        let url = try XCTUnwrap(
            URL(
                string: "moist://login-callback"
            )
        )

        XCTAssertEqual(
            RawdeaAuthCallbackRoute(url: url),
            .login
        )
    }

    func testPasswordRecoveryCallback() throws {

        let url = try XCTUnwrap(
            URL(
                string:
                    "rawdea://password-recovery?code=test"
            )
        )

        XCTAssertEqual(
            RawdeaAuthCallbackRoute(url: url),
            .passwordRecovery
        )
    }

    func testUnrecognizedHostIsRejected() throws {

        let url = try XCTUnwrap(
            URL(
                string: "rawdea://unknown"
            )
        )

        XCTAssertNil(
            RawdeaAuthCallbackRoute(url: url)
        )
    }

    func testUnrecognizedSchemeIsRejected() throws {

        let url = try XCTUnwrap(
            URL(
                string: "https://password-recovery"
            )
        )

        XCTAssertNil(
            RawdeaAuthCallbackRoute(url: url)
        )
    }

    func testUnexpectedLegacyRecoveryIsRejected() throws {

        let url = try XCTUnwrap(
            URL(
                string:
                    "moist://password-recovery"
            )
        )

        XCTAssertNil(
            RawdeaAuthCallbackRoute(url: url)
        )
    }
}

