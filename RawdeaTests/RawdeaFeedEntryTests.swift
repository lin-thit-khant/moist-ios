//
//  RawdeaFeedEntryTests.swift
//  Rawdea
//

import XCTest
@testable import Rawdea

final class RawdeaFeedEntryTests: XCTestCase {

    private let first = PostProject(id: UUID(), name: "First")
    private let second = PostProject(id: UUID(), name: "Second")

    private func post(in project: PostProject?) -> Post {
        Post(
            id: UUID(),
            userId: UUID(),
            content: "Hello",
            createdAt: Date(),
            projectId: project?.id,
            project: project
        )
    }

    /// "post" rows read as P (Project line shown) or p, plus "|"
    /// when the thread continues. "+N" is the cut-short row.
    private func shape(_ posts: [Post]) -> [String] {
        RawdeaFeedEntry.entries(for: posts).map { entry in
            switch entry {
            case .post(_, let showsProject, let continues):
                return (showsProject ? "P" : "p") + (continues ? "|" : "")
            case .more(_, let count, _):
                return "+\(count)"
            }
        }
    }

    func testPostsWithoutAProjectNeverJoin() {
        XCTAssertEqual(shape([post(in: nil), post(in: nil)]), ["P", "P"])
    }

    func testNeighboursInOneProjectJoin() {
        XCTAssertEqual(shape([post(in: first), post(in: first)]), ["P|", "p"])
    }

    func testLongThreadIsCutShort() {
        let posts = (0..<5).map { _ in post(in: first) }
        XCTAssertEqual(shape(posts), ["P|", "p|", "+3"])
    }

    func testAnotherProjectOrAPlainPostBreaksTheThread() {
        let posts = [post(in: first), post(in: second), post(in: nil), post(in: second)]
        XCTAssertEqual(shape(posts), ["P", "P", "P", "P"])
    }

    func testRowIdentifiersAreUnique() {
        let posts = (0..<4).map { _ in post(in: first) }
        let ids = RawdeaFeedEntry.entries(for: posts).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
