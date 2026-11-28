import XCTest
@testable import Rawdea

/// Run before submitting:
/// TEST_RUNNER_RAWDEA_RELEASE_CHECK=1 xcodebuild test ... -only-testing:RawdeaTests/ReleaseReadinessTests
final class ReleaseReadinessTests: XCTestCase {

    func testPublicContactIsConfigured() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RAWDEA_RELEASE_CHECK"] == "1",
            "Set RAWDEA_RELEASE_CHECK=1 to check release settings."
        )

        let email = RawdeaPublicContact.email
        XCTAssertNotNil(
            email.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression),
            "email is missing or invalid"
        )

        for (name, value) in [
            ("supportURL", RawdeaPublicContact.supportURL),
            ("privacyPolicyURL", RawdeaPublicContact.privacyPolicyURL),
            ("termsURL", RawdeaPublicContact.termsURL)
        ] {
            let url = URL(string: value)
            XCTAssertTrue(
                url?.scheme == "https" && url?.host?.isEmpty == false,
                "\(name) is missing or not an https URL"
            )
        }
    }
}
