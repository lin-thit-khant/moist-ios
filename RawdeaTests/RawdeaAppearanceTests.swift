//
//  RawdeaAppearanceTests.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 25/11/2569 BE.
//

import SwiftUI
import XCTest
@testable import Rawdea

final class RawdeaAppearanceTests: XCTestCase {

    func testSystemAppearanceUsesDevicePreference() {

        XCTAssertNil(
            RawdeaAppearance.system
                .preferredColorScheme
        )
    }

    func testLightAppearance() {

        XCTAssertEqual(
            RawdeaAppearance.light
                .preferredColorScheme,
            ColorScheme.light
        )
    }

    func testDarkAppearance() {

        XCTAssertEqual(
            RawdeaAppearance.dark
                .preferredColorScheme,
            ColorScheme.dark
        )
    }

    func testStoredValuesCanBeRestored() {

        for appearance in
            RawdeaAppearance.allCases {

            XCTAssertEqual(
                RawdeaAppearance(
                    rawValue: appearance.rawValue
                ),
                appearance
            )
        }
    }

    func testInvalidStoredValueUsesSystemFallback() {

        let appearance =
            RawdeaAppearance(
                rawValue: "unknown"
            ) ?? .system

        XCTAssertEqual(
            appearance,
            .system
        )
    }
}

