import XCTest
@testable import Rawdea

@MainActor
final class RawdeaTermsAgreementTests: XCTestCase {

    func testOnlySignUpNeedsTheTick() {
        XCTAssertFalse(RawdeaAuthFormMode.signUp.termsSatisfied(accepted: false))
        XCTAssertTrue(RawdeaAuthFormMode.signUp.termsSatisfied(accepted: true))

        for mode in [RawdeaAuthFormMode.login, .forgotPassword, .resetPassword] {
            XCTAssertTrue(mode.termsSatisfied(accepted: false))
        }
    }

    func testTermsLinksOnlyWhenAnHTTPSPageIsSet() {
        XCTAssertNil(RawdeaTermsAgreementRow.termsLink(""))
        XCTAssertNil(RawdeaTermsAgreementRow.termsLink("http://example.com/terms"))

        let plain = RawdeaTermsAgreementRow.attributedStatement(termsURL: nil)
        XCTAssertEqual(plain.runs.compactMap(\.link).count, 1)

        let url = RawdeaTermsAgreementRow.termsLink("https://example.com/terms")
        let linked = RawdeaTermsAgreementRow.attributedStatement(termsURL: url)
        XCTAssertEqual(linked.runs.compactMap(\.link).count, 2)
    }
}
