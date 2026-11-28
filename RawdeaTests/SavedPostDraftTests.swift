import XCTest
@testable import Rawdea

final class SavedPostDraftTests: XCTestCase {

    func testDraftSurvivesReloadAndIsScopedToAccount() throws {
        let suite = "RawdeaDraftTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let user = UUID()
        let anotherUser = UUID()
        let draft = SavedPostDraft(content: "  Work in progress\n", projectId: UUID(), kind: .progress)

        SavedPostDraft.save(draft, for: user, defaults: defaults)

        let reopened = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(SavedPostDraft.load(for: user, defaults: reopened), draft)
        XCTAssertNil(SavedPostDraft.load(for: anotherUser, defaults: reopened))

        SavedPostDraft.save(nil, for: user, defaults: reopened)
        XCTAssertNil(SavedPostDraft.load(for: user, defaults: defaults))
    }
}
