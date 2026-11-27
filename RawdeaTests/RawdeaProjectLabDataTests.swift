//
//  RawdeaProjectLabDataTests.swift
//  Rawdea
//
//  Runs against local Supabase only. Each test creates its own accounts
//  and deletes them afterwards, which removes everything they made.
//
//  Skipped unless the local service role key is passed in, for cleanup:
//  TEST_RUNNER_RAWDEA_LOCAL_SERVICE_KEY=<key> xcodebuild test ...
//

import Supabase
import XCTest
@testable import Rawdea

@MainActor
final class RawdeaProjectLabDataTests: XCTestCase {

    private var userIds: [UUID] = []
    private var supabaseURL: URL!
    private var publishableKey = ""
    private var serviceKey = ""

    override func setUpWithError() throws {

        guard let key = ProcessInfo.processInfo
            .environment["RAWDEA_LOCAL_SERVICE_KEY"], !key.isEmpty else {
            throw XCTSkip("Local service role key not provided.")
        }

        let url = try XCTUnwrap(
            (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String)
                .flatMap(URL.init(string:))
        )

        guard url.host == "127.0.0.1" else {
            throw XCTSkip("These tests only run against local Supabase.")
        }

        serviceKey = key
        supabaseURL = url
        publishableKey = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "SUPABASE_KEY") as? String
        )
    }

    override func tearDown() async throws {

        for id in userIds {
            var request = URLRequest(
                url: supabaseURL.appending(path: "auth/v1/admin/users/\(id)")
            )
            request.httpMethod = "DELETE"
            request.setValue(serviceKey, forHTTPHeaderField: "apikey")
            request.setValue(
                "Bearer \(serviceKey)",
                forHTTPHeaderField: "Authorization"
            )

            let (_, response) = try await URLSession.shared.data(for: request)

            XCTAssertEqual(
                (response as? HTTPURLResponse)?.statusCode, 200,
                "Fixture account was not removed: \(id)"
            )
        }

        userIds = []
    }

    // MARK: - Default Project

    func testPostWithoutProjectUsesOneDefaultProject() async throws {

        let owner = try await makeUser()

        let first = try await owner.posts.createPost(content: "Loose one")
        let second = try await owner.posts.createPost(content: "Loose two")

        let defaultId = try XCTUnwrap(first.projectId)
        XCTAssertEqual(second.projectId, defaultId)
        XCTAssertEqual(first.kind, .note)

        let projects = try await owner.projects.fetchProjects(userId: owner.id)

        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.isDefault, true)
        XCTAssertEqual(projects.first?.stage, .early)

        let other = try await owner.projects.createProject(name: "Other")
        XCTAssertFalse(other.isDefault)

        try await owner.posts.movePost(postId: first.id, to: other.id)
        try await owner.posts.movePost(postId: first.id, to: nil)

        let moved = try await owner.posts.fetchPost(postId: first.id)
        XCTAssertEqual(moved?.projectId, defaultId)

        // A client cannot claim or release the default flag.
        try await owner.client.from("projects")
            .update(["is_default": true])
            .eq("id", value: other.id)
            .execute()

        let unchanged = try await owner.projects.fetchProject(id: other.id)
        XCTAssertFalse(unchanged.isDefault)

        await assertThrows("A Project with posts cannot be deleted") {
            try await owner.client.from("projects")
                .delete()
                .eq("id", value: defaultId)
                .execute()
        }
    }

    // MARK: - Stages

    func testOnlyOwnerChangesStageAndHistoryFollowsVisibility() async throws {

        let owner = try await makeUser()
        let reader = try await makeUser()

        let project = try await owner.projects.createProject(name: "Lab")
        let post = try await owner.posts.createPost(
            content: "Started building",
            projectId: project.id,
            kind: .progress
        )
        let elsewhere = try await owner.posts.createPost(content: "Elsewhere")

        XCTAssertEqual(post.kind, .progress)

        await assertThrows("Another user cannot change the stage") {
            _ = try await reader.projects.setStage(
                projectId: project.id, stage: .shipped
            )
        }

        try await reader.client.from("projects")
            .update(["stage": "shipped"])
            .eq("id", value: project.id)
            .execute()

        await assertThrows("The post must belong to the Project") {
            _ = try await owner.projects.setStage(
                projectId: project.id,
                stage: .inProgress,
                postId: elsewhere.id
            )
        }

        let updated = try await owner.projects.setStage(
            projectId: project.id, stage: .inProgress, postId: post.id
        )

        XCTAssertEqual(updated.stage, .inProgress)
        XCTAssertGreaterThan(updated.stageChangedAt, project.stageChangedAt)

        let renamed = try await owner.projects.renameProject(
            projectId: project.id, name: "Lab two"
        )
        XCTAssertEqual(renamed.stageChangedAt, updated.stageChangedAt)

        let events = try await reader.projects
            .fetchStageEvents(projectId: project.id)

        XCTAssertEqual(events.map(\.toStage), [.inProgress])
        XCTAssertEqual(events.first?.fromStage, .early)
        XCTAssertEqual(events.first?.postId, post.id)

        await assertThrows("Clients cannot write history") {
            try await owner.client.from("project_stage_events")
                .insert([
                    "project_id": project.id.uuidString,
                    "from_stage": "early",
                    "to_stage": "shipped"
                ])
                .execute()
        }

        _ = try await owner.projects.setHidden(
            projectId: project.id, hidden: true
        )

        let hidden = try await reader.projects
            .fetchStageEvents(projectId: project.id)
        XCTAssertTrue(hidden.isEmpty)

        _ = try await owner.projects.setHidden(
            projectId: project.id, hidden: false
        )
        try await reader.blocks.blockUser(userId: owner.id)

        let blocked = try await reader.projects
            .fetchStageEvents(projectId: project.id)
        XCTAssertTrue(blocked.isEmpty)
    }

    // MARK: - Best Reply

    func testOnlyQuestionAuthorChoosesBestReply() async throws {

        let author = try await makeUser()
        let replier = try await makeUser()

        let question = try await author.posts.createPost(
            content: "Which one?", kind: .question
        )
        let note = try await author.posts.createPost(content: "Just a note")

        let reply = try await replier.engagement.addComment(
            postId: question.id, content: "The first"
        )
        let noteReply = try await replier.engagement.addComment(
            postId: note.id, content: "Nice"
        )

        await assertThrows("Another user cannot choose") {
            try await replier.posts.setBestReply(
                postId: question.id, commentId: reply.id
            )
        }
        await assertThrows("A note has no best reply") {
            try await author.posts.setBestReply(
                postId: note.id, commentId: noteReply.id
            )
        }
        await assertThrows("The reply must belong to the question") {
            try await author.posts.setBestReply(
                postId: question.id, commentId: noteReply.id
            )
        }

        func bestReply() async throws -> UUID? {
            try await author.posts.fetchPost(postId: question.id)?.bestReplyId
        }

        try await author.posts.setBestReply(
            postId: question.id, commentId: reply.id
        )
        var chosen = try await bestReply()
        XCTAssertEqual(chosen, reply.id)

        try await author.posts.setBestReply(
            postId: question.id, commentId: nil
        )
        chosen = try await bestReply()
        XCTAssertNil(chosen)

        try await author.posts.setBestReply(
            postId: question.id, commentId: reply.id
        )
        try await author.client.from("posts")
            .update(["kind": "decision"])
            .eq("id", value: question.id)
            .execute()
        chosen = try await bestReply()
        XCTAssertNil(chosen)

        try await author.client.from("posts")
            .update(["kind": "question"])
            .eq("id", value: question.id)
            .execute()
        try await author.posts.setBestReply(
            postId: question.id, commentId: reply.id
        )
        try await replier.engagement.deleteComment(commentId: reply.id)
        chosen = try await bestReply()
        XCTAssertNil(chosen)
    }

    // MARK: - Last Seen

    func testLastSeenIsServerStampedAndPrivate() async throws {

        let owner = try await makeUser()
        let reader = try await makeUser()

        let project = try await owner.projects.createProject(name: "Seen")
        try await reader.following.followProject(projectId: project.id)

        var seen = try await reader.following.fetchProjectLastSeen()
        XCTAssertNil(seen[project.id])

        try await reader.following.markProjectSeen(projectId: project.id)

        seen = try await reader.following.fetchProjectLastSeen()
        XCTAssertNotNil(seen[project.id])

        // A client-chosen time is replaced by the server's.
        try await reader.client.from("project_follows")
            .update(
                ["last_seen_at": "2000-01-01T00:00:00Z"],
                returning: .minimal
            )
            .eq("project_id", value: project.id)
            .execute()

        let restamped = try await reader.following.fetchProjectLastSeen()
        XCTAssertGreaterThan(
            try XCTUnwrap(restamped[project.id]),
            try XCTUnwrap(seen[project.id])
        )

        await assertThrows("Others cannot read when someone looked") {
            try await owner.client.from("project_follows")
                .select("last_seen_at")
                .eq("project_id", value: project.id)
                .execute()
        }

        let ownersView = try await owner.following.fetchProjectLastSeen()
        XCTAssertTrue(ownersView.isEmpty)

        let followers = try await owner.following
            .projectFollowerCount(projectId: project.id)
        XCTAssertEqual(followers, 1)

        let followed = try await reader.following.fetchFollowingProjects()
        XCTAssertEqual(followed.map(\.id), [project.id])
        XCTAssertEqual(followed.first?.stage, .early)

        try await reader.following.unfollowProject(projectId: project.id)

        let stillFollowing = try await reader.following
            .isFollowingProject(projectId: project.id)
        XCTAssertFalse(stillFollowing)
    }

    // MARK: - Activity

    func testActivityForAnswersStagesAndPreferences() async throws {

        let owner = try await makeUser()
        let reader = try await makeUser()

        let project = try await owner.projects.createProject(name: "Bell")
        let question = try await owner.posts.createPost(
            content: "Which one?", projectId: project.id, kind: .question
        )
        try await reader.following.followProject(projectId: project.id)

        // Follows a different Project, so hears nothing about this one.
        let bystander = try await makeUser()
        let other = try await owner.projects.createProject(name: "Other")
        try await bystander.following.followProject(projectId: other.id)

        let reply = try await reader.engagement.addComment(
            postId: question.id, content: "That one"
        )
        try await owner.posts.setBestReply(
            postId: question.id, commentId: reply.id
        )
        try await owner.posts.setBestReply(
            postId: question.id, commentId: nil
        )
        try await owner.posts.setBestReply(
            postId: question.id, commentId: reply.id
        )
        _ = try await owner.projects.setStage(
            projectId: project.id, stage: .inProgress
        )
        _ = try await owner.projects.setStage(
            projectId: project.id, stage: .shipped
        )

        let received = try await reader.activity.fetchNotifications()

        XCTAssertEqual(
            received.filter { $0.kind == .bestAnswer }.count, 1,
            "Choosing again does not notify twice"
        )
        let moves = received.filter { $0.kind == .stageChange }
        XCTAssertEqual(moves.map(\.stage), [.shipped])
        XCTAssertEqual(moves.first?.message, "Bell moved to Shipped")

        let unrelated = try await bystander.activity.fetchNotifications()
        XCTAssertTrue(unrelated.isEmpty)

        let ownerReceived = try await owner.activity.fetchNotifications()
        let answer = try XCTUnwrap(
            ownerReceived.first { $0.kind == .postComment }
        )
        XCTAssertTrue(answer.matches(.answers))

        // A hidden Project takes its notification with it.
        _ = try await owner.projects.setHidden(
            projectId: project.id, hidden: true
        )
        let whileHidden = try await reader.activity.fetchNotifications()
        XCTAssertFalse(whileHidden.contains { $0.kind == .stageChange })
        _ = try await owner.projects.setHidden(
            projectId: project.id, hidden: false
        )

        // Preferences: private to their owner, applied by the server.
        var preferences = try await owner.activity.fetchPreferences()
        XCTAssertEqual(preferences, NotificationPreferences())

        preferences.likes = false
        preferences.answers = false
        try await owner.activity.savePreferences(preferences)
        let saved = try await owner.activity.fetchPreferences()
        XCTAssertEqual(saved, preferences)

        let othersView: [NotificationPreferences] = try await reader.client
            .from("notification_preferences")
            .select()
            .eq("user_id", value: owner.id)
            .execute()
            .value
        XCTAssertTrue(othersView.isEmpty)

        await assertThrows("Another user cannot write preferences") {
            try await reader.client.from("notification_preferences")
                .insert(["user_id": owner.id.uuidString])
                .execute()
        }

        try await reader.engagement.like(postId: question.id)
        _ = try await reader.engagement.addComment(
            postId: question.id, content: "Also this"
        )

        let after = try await owner.activity.fetchNotifications()
        XCTAssertEqual(after.count, ownerReceived.count)

        await assertThrows("Clients cannot create notifications") {
            try await reader.client.from("notifications")
                .insert([
                    "recipient_id": owner.id.uuidString,
                    "actor_id": reader.id.uuidString,
                    "kind": "user_follow"
                ])
                .execute()
        }

        // Replies and Explore read only what is visible.
        let replies = try await owner.engagement
            .fetchReplies(userId: reader.id)
        XCTAssertEqual(replies.count, 2)

        let discovery = DiscoveryService(client: reader.client)
        let active = try await discovery.fetchActiveProjects(stage: .shipped)
        XCTAssertTrue(active.contains { $0.id == project.id })

        try await reader.blocks.blockUser(userId: owner.id)

        let blockedActive = try await discovery
            .fetchActiveProjects(stage: .shipped)
        XCTAssertFalse(blockedActive.contains { $0.id == project.id })

        let blockedReplies = try await owner.engagement
            .fetchReplies(userId: reader.id)
        XCTAssertTrue(blockedReplies.isEmpty)
    }

    func testOpenQuestionsLeaveOutAnsweredOnes() async throws {

        let owner = try await makeUser()
        let question = try await owner.posts.createPost(
            content: "Still open?", kind: .question
        )

        let open = try await DiscoveryService(client: owner.client)
            .fetchOpenQuestions()

        XCTAssertTrue(open.contains { $0.id == question.id })
    }

    // MARK: - Fixtures

    @MainActor
    private struct TestUser {
        let id: UUID
        let client: SupabaseClient

        var posts: PostService { PostService(client: client) }
        var projects: ProjectService { ProjectService(client: client) }
        var following: FollowingService { FollowingService(client: client) }
        var blocks: BlockService { BlockService(client: client) }
        var activity: NotificationService {
            NotificationService(client: client)
        }
        var engagement: PostEngagementService {
            PostEngagementService(client: client)
        }
    }

    private func makeUser() async throws -> TestUser {

        // In-memory storage leaves the app's own session untouched.
        let client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(storage: MemoryAuthStorage())
            )
        )

        let response = try await client.auth.signUp(
            email: "projectlab-\(UUID().uuidString.lowercased())@example.test",
            password: UUID().uuidString
        )

        userIds.append(response.user.id)

        return TestUser(id: response.user.id, client: client)
    }

    private func assertThrows(
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ work: () async throws -> Void
    ) async {
        do {
            try await work()
            XCTFail(message, file: file, line: line)
        } catch {}
    }
}

private final class MemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {

    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        lock.withLock { values[key] = nil }
    }
}
