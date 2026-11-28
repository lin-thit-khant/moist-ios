//
//  RawdeaCollaborationTests.swift
//  Rawdea
//
//  Models and view models for suggestions, contributors and cycles.
//

import XCTest
@testable import Rawdea

@MainActor
final class RawdeaCollaborationTests: XCTestCase {

    private let projectId = UUID()
    private let now = Date()

    // MARK: - Models

    func testCreditNamesReadAsASentence() {
        XCTAssertEqual(CreditNames.sentence([]), "")
        XCTAssertEqual(CreditNames.sentence(["maya"]), "maya")
        XCTAssertEqual(CreditNames.sentence(["maya", "ravi"]), "maya and ravi")
        XCTAssertEqual(
            CreditNames.sentence(["maya", "tom", "ravi"]),
            "maya, tom and ravi"
        )
    }

    func testStageMarkerNamesCreditOrStartsACycle() {
        var move = event(to: .inProgress)
        XCTAssertEqual(move.marker, "Moved to In progress")

        move.credits = [credit("ravi"), credit("maya")]
        XCTAssertEqual(move.marker, "Moved to In progress · with maya and ravi")

        var start = event(to: .early, cycle: 2)
        start.startsCycle = true
        start.cycleName = "Winter"
        XCTAssertEqual(start.marker, "Started Cycle 2: Winter")
        start.cycleName = nil
        XCTAssertEqual(start.marker, "Started Cycle 2")
    }

    func testProjectOpennessToSuggestionsAndContributors() {
        XCTAssertTrue(project().takesSuggestions)
        XCTAssertTrue(project().takesContributions)

        var off = project()
        off.suggestionsEnabled = false
        XCTAssertFalse(off.takesSuggestions)
        XCTAssertTrue(off.takesContributions)

        for closed in [
            project(stage: .shipped), project(isHidden: true),
            project(isArchived: true), project(isDefault: true)
        ] {
            XCTAssertFalse(closed.takesSuggestions)
            XCTAssertFalse(closed.takesContributions)
        }
    }

    func testUndoIsOfferedForOneDayAfterANewCycle() {
        var second = project()
        XCTAssertFalse(second.canOfferUndoCycle(at: now))

        second.cycle = 2
        second.cycleStartedAt = now
        XCTAssertTrue(second.canOfferUndoCycle(at: now.addingTimeInterval(86_399)))
        XCTAssertFalse(second.canOfferUndoCycle(at: now.addingTimeInterval(86_400)))
    }

    func testCycleChoices() {
        XCTAssertEqual(CycleChoice.all.numbers(current: 3), [3, 2, 1])
        XCTAssertEqual(CycleChoice.current.numbers(current: 3), [3])
        XCTAssertEqual(CycleChoice.past(1).numbers(current: 3), [1])
        XCTAssertEqual(CycleChoice.current.title(current: 2), "Cycle 2")
    }

    func testRecapCountsOnlyItsCycle() {
        let shipped = event(to: .shipped, at: 200)
        var restart = event(to: .inProgress, at: 300, cycle: 2)
        restart.startsCycle = true

        let recap = CycleRecap(
            number: 1,
            projectStartedAt: Date(timeIntervalSince1970: 0),
            posts: [
                post(kind: .decision, cycle: 1),
                post(kind: .note, cycle: 1),
                post(kind: .decision, cycle: 2)
            ],
            events: [restart, shipped, event(to: .inProgress, at: 100)]
        )

        XCTAssertEqual(recap.postCount, 2)
        XCTAssertEqual(recap.decisions.count, 1)
        XCTAssertEqual(recap.moves.map(\.toStage), [.shipped, .inProgress])
        XCTAssertEqual(recap.shippedAt, shipped.createdAt)
        XCTAssertEqual(recap.startedAt, Date(timeIntervalSince1970: 0))
    }

    func testCandidatesSkipPeopleWhoHoldAPlace() {
        let maya = UUID(), ravi = UUID(), tom = UUID()
        let candidates = ContributorCandidate.from(
            approved: [
                suggestion(by: ravi, "ravi"),
                suggestion(by: maya, "maya"),
                suggestion(by: ravi, "ravi"),
                suggestion(by: tom, "tom")
            ],
            members: [
                member(tom, .invited),
                member(maya, .left)
            ]
        )

        XCTAssertEqual(candidates.map(\.username), ["ravi", "maya"])
        XCTAssertEqual(candidates.map(\.approvedCount), [2, 1])
    }

    func testContributedToDetail() {
        var item = ContributedProject(
            projectId: projectId, projectName: "Ledger",
            ownerUsername: "lin", isContributor: true
        )
        item.cycles = [1, 2]
        XCTAssertEqual(item.detail, "by lin · Cycles 1, 2 · contributor")
    }

    func testCollaborationActivityRows() {
        let waiting = notification(.suggestionsWaiting, count: 2)
        XCTAssertEqual(waiting.message, "Ledger has 2 new suggestions")
        XCTAssertTrue(waiting.matches(.projects))

        var credited = notification(.credited)
        credited.stage = .shipped
        XCTAssertEqual(credited.message, "Ledger moved to Shipped. You're credited.")

        XCTAssertEqual(
            notification(.cycleStarted, count: 2).message,
            "Ledger started Cycle 2"
        )
        XCTAssertEqual(
            notification(.contributorInvite).message,
            "lin invited you to contribute to Ledger"
        )
    }

    func testServerRefusalsReadPlainly() {
        func message(_ marker: String) -> String {
            CollaborationErrorMessage.from(Refusal(marker: marker))
        }
        XCTAssertTrue(message("RAWDEA_SUGGESTION_LIMIT").contains("3 suggestions"))
        XCTAssertTrue(message("RAWDEA_CONTRIBUTORS_FULL").contains("5 contributors"))
        XCTAssertTrue(message("RAWDEA_CYCLE_TOO_SOON").contains("30 days"))
        XCTAssertTrue(message("RAWDEA_FILTER_HELD:several_links").contains("opening note"))
    }

    // MARK: - Suggestion view models

    func testSendingTrimsAndRefusesDecisions() async {
        let service = FakeSuggestions()
        let model = SuggestUpdateViewModel(service: service)

        let decision = await model.send(
            projectId: projectId, kind: .decision, content: "No"
        )
        let empty = await model.send(
            projectId: projectId, kind: .note, content: "  "
        )
        XCTAssertFalse(decision)
        XCTAssertFalse(empty)
        XCTAssertTrue(service.calls.isEmpty)

        let sent = await model.send(
            projectId: projectId, kind: .note, content: "  Try this  "
        )
        XCTAssertTrue(sent)
        XCTAssertEqual(service.calls, ["suggest Try this"])
    }

    func testFailedSendKeepsAMessage() async {
        let service = FakeSuggestions()
        service.failure = Refusal(marker: "RAWDEA_SUGGESTION_LIMIT")
        let model = SuggestUpdateViewModel(service: service)

        let sent = await model.send(projectId: projectId, kind: .note, content: "x")

        XCTAssertFalse(sent)
        XCTAssertTrue(model.errorMessage?.contains("3 suggestions") == true)
        XCTAssertFalse(model.isSending)
    }

    func testListScopesAndAnswers() async {
        let service = FakeSuggestions()
        let item = suggestion(by: UUID(), "maya")
        service.items = [item]

        let review = SuggestionListViewModel(
            scope: .review(projectId: projectId), service: service
        )
        await review.load()
        await review.decide(item, approve: true)
        await review.block(item)

        let mine = SuggestionListViewModel(
            scope: .mine(projectId: nil), service: service
        )
        await mine.load()
        await mine.withdraw(item)

        XCTAssertEqual(service.calls, [
            "waiting", "approve", "waiting", "block", "waiting",
            "mine", "withdraw", "mine"
        ])
        XCTAssertTrue(review.hasLoaded)
    }

    func testFailedAnswerReloadsAndSaysWhy() async {
        let service = FakeSuggestions()
        let item = suggestion(by: UUID(), "maya")
        let model = SuggestionListViewModel(
            scope: .review(projectId: projectId), service: service
        )
        service.actionFailure = Refusal(marker: "RAWDEA_SUGGESTION_CHANGED")

        await model.decide(item, approve: false)

        XCTAssertEqual(service.calls, ["waiting"])
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.busyId)
    }

    // MARK: - Contributor view models

    func testContributorPlacesAndCap() async {
        let service = FakeContributors()
        service.members = (0..<5).map { index in
            member(UUID(), index == 4 ? .active : .invited)
        } + [member(UUID(), .removed)]
        let model = ContributorsViewModel(projectId: projectId, service: service)

        await model.load()

        XCTAssertEqual(model.places.count, 5)
        XCTAssertEqual(model.places.first?.status, .active)
        XCTAssertTrue(model.isFull)
    }

    func testOwnerInvitesAndRemoves() async {
        let service = FakeContributors()
        let model = ContributorsViewModel(projectId: projectId, service: service)
        let person = UUID()

        await model.invite(userId: person)
        await model.remove(userId: person, hidePosts: true)

        XCTAssertEqual(service.calls, ["invite", "remove true"])
    }

    func testInviteeAnswersAndLeaves() async {
        let service = FakeContributors()
        service.mine = member(UUID(), .invited)
        let model = MembershipViewModel(projectId: projectId, service: service)

        await model.load()
        XCTAssertEqual(model.status, .invited)

        let accepted = await model.respond(accept: true)
        let left = await model.leave()

        XCTAssertTrue(accepted)
        XCTAssertTrue(left)
        XCTAssertEqual(service.calls, ["respond true", "leave"])

        service.failure = Refusal(marker: "RAWDEA_INVITE_CHANGED")
        let again = await model.respond(accept: false)
        XCTAssertFalse(again)
        XCTAssertNotNil(model.errorMessage)
    }

    // MARK: - Start cycle

    func testCycleNeedsANoteAndAShortName() async {
        let service = FakeCycles(result: project())
        let model = StartCycleViewModel(service: service)

        XCTAssertEqual(model.stage, .inProgress)
        XCTAssertFalse(model.canStart)

        model.note = "Next round"
        model.name = String(repeating: "n", count: 61)
        XCTAssertFalse(model.canStart)

        model.name = "  Winter  "
        await model.start(projectId: projectId)
        await model.start(projectId: projectId)

        XCTAssertEqual(service.calls, ["Next round|Winter|in_progress"])
        XCTAssertNotNil(model.started)
    }

    func testRefusedCycleKeepsTheForm() async {
        let service = FakeCycles(result: project())
        service.failure = Refusal(marker: "RAWDEA_CYCLE_TOO_SOON")
        let model = StartCycleViewModel(service: service)
        model.note = "Soon"

        await model.start(projectId: projectId)

        XCTAssertNil(model.started)
        XCTAssertTrue(model.errorMessage?.contains("30 days") == true)
        XCTAssertTrue(model.canStart)
    }

    // MARK: - Fixtures

    private func project(
        stage: ProjectStage = .early,
        isHidden: Bool = false,
        isArchived: Bool = false,
        isDefault: Bool = false
    ) -> Project {
        Project(
            id: projectId, userId: UUID(), name: "Ledger", createdAt: now,
            isArchived: isArchived, isHidden: isHidden, isPinned: false,
            stage: stage, stageChangedAt: now, isDefault: isDefault
        )
    }

    private func event(
        to stage: ProjectStage,
        at time: TimeInterval = 0,
        cycle: Int = 1
    ) -> ProjectStageEvent {
        var event = ProjectStageEvent(
            id: UUID(), projectId: projectId, fromStage: .early,
            toStage: stage, postId: nil,
            createdAt: Date(timeIntervalSince1970: time)
        )
        event.cycle = cycle
        return event
    }

    private func credit(_ name: String) -> StageCredit {
        StageCredit(userId: UUID(), person: .init(username: name))
    }

    private func post(kind: PostKind, cycle: Int) -> Post {
        var post = Post(id: UUID(), userId: UUID(), content: "p", createdAt: now)
        post.kind = kind
        post.cycle = cycle
        return post
    }

    private func suggestion(by userId: UUID, _ name: String) -> ProjectSuggestion {
        var item = ProjectSuggestion(
            id: UUID(), projectId: projectId, userId: userId,
            kind: .note, content: "idea", status: .waiting, createdAt: now
        )
        item.author = PostAuthor(id: userId, displayName: name, username: name)
        return item
    }

    private func member(_ userId: UUID, _ status: MemberStatus) -> ProjectMember {
        ProjectMember(projectId: projectId, userId: userId, status: status)
    }

    private func notification(
        _ kind: RawdeaNotificationKind,
        count: Int? = nil
    ) -> RawdeaNotification {
        var item = RawdeaNotification(
            id: UUID(), recipientId: UUID(), actorId: UUID(), kind: kind,
            postId: nil, projectId: projectId, isRead: false, createdAt: now,
            actor: PostAuthor(id: UUID(), displayName: "Lin", username: "lin")
        )
        item.project = NotificationProject(name: "Ledger")
        item.itemCount = count
        return item
    }
}

private struct Refusal: LocalizedError {
    let marker: String
    var errorDescription: String? { marker }
}

private final class FakeSuggestions: SuggestionServicing {
    var items: [ProjectSuggestion] = []
    var calls: [String] = []
    var failure: Error?
    var actionFailure: Error?

    private func record(_ call: String) throws {
        if let failure { throw failure }
        calls.append(call)
    }

    private func act(_ call: String) throws {
        if let actionFailure { throw actionFailure }
        try record(call)
    }

    func suggest(projectId: UUID, kind: PostKind, content: String) async throws {
        try act("suggest \(content)")
    }
    func fetchWaiting(projectId: UUID) async throws -> [ProjectSuggestion] {
        try record("waiting")
        return items
    }
    func fetchMine(projectId: UUID?) async throws -> [ProjectSuggestion] {
        try record("mine")
        return items
    }
    func withdraw(id: UUID) async throws { try act("withdraw") }
    func decide(id: UUID, approve: Bool) async throws {
        try act(approve ? "approve" : "decline")
    }
    func block(userId: UUID) async throws { try act("block") }
}

private final class FakeContributors: ContributorServicing {
    var members: [ProjectMember] = []
    var mine: ProjectMember?
    var calls: [String] = []
    var failure: Error?

    private func act(_ call: String) throws {
        if let failure { throw failure }
        calls.append(call)
    }

    func fetchMembers(projectId: UUID) async throws -> [ProjectMember] { members }
    func fetchApprovedSuggestions(projectId: UUID) async throws -> [ProjectSuggestion] { [] }
    func invite(projectId: UUID, userId: UUID) async throws { try act("invite") }
    func remove(projectId: UUID, userId: UUID, hidePosts: Bool) async throws {
        try act("remove \(hidePosts)")
    }
    func fetchMyMembership(projectId: UUID) async throws -> ProjectMember? { mine }
    func respond(projectId: UUID, accept: Bool) async throws {
        try act("respond \(accept)")
    }
    func leave(projectId: UUID) async throws { try act("leave") }
}

private final class FakeCycles: CycleServicing {
    let result: Project
    var calls: [String] = []
    var failure: Error?

    init(result: Project) { self.result = result }

    func startCycle(
        projectId: UUID,
        note: String,
        name: String,
        stage: ProjectStage
    ) async throws -> Project {
        if let failure { throw failure }
        calls.append("\(note)|\(name)|\(stage.rawValue)")
        return result
    }
}
