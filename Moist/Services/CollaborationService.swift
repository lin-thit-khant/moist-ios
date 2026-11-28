//
//  CollaborationService.swift
//  Rawdea
//

import Foundation
import Supabase

protocol ContributorServicing {
    func fetchMembers(projectId: UUID) async throws -> [ProjectMember]
    func fetchApprovedSuggestions(projectId: UUID) async throws -> [ProjectSuggestion]
    func invite(projectId: UUID, userId: UUID) async throws
    func remove(projectId: UUID, userId: UUID, hidePosts: Bool) async throws
    func fetchMyMembership(projectId: UUID) async throws -> ProjectMember?
    func respond(projectId: UUID, accept: Bool) async throws
    func leave(projectId: UUID) async throws
}

/// Contributors, the owner's say over posts, and credit.
/// The server enforces every rule.
struct CollaborationService: ContributorServicing {

    private static let memberSelection = """
        project_id,
        user_id,
        status,
        person: profiles!project_members_user_id_fkey(id, display_name, username)
        """

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }

    // MARK: - Members

    func fetchMembers(projectId: UUID) async throws -> [ProjectMember] {
        try await client
            .from("project_members")
            .select(Self.memberSelection)
            .eq("project_id", value: projectId)
            .order("invited_at", ascending: true)
            .execute()
            .value
    }

    func fetchMyMembership(projectId: UUID) async throws -> ProjectMember? {
        let userId = try await client.auth.session.user.id
        let rows: [ProjectMember] = try await client
            .from("project_members")
            .select(Self.memberSelection)
            .eq("project_id", value: projectId)
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.first
    }

    /// Projects the viewer can post in as a contributor right now.
    func fetchContributingProjects() async throws -> [Project] {
        let userId = try await client.auth.session.user.id
        let rows: [MembershipProject] = try await client
            .from("project_members")
            .select("project: projects!project_members_project_id_fkey(*)")
            .eq("user_id", value: userId)
            .eq("status", value: MemberStatus.active.rawValue)
            .execute()
            .value
        return rows
            .compactMap(\.project)
            .filter(\.takesContributions)
            .sorted { $0.name < $1.name }
    }

    func fetchApprovedSuggestions(projectId: UUID) async throws -> [ProjectSuggestion] {
        try await client
            .from("project_suggestions")
            .select("*, author: profiles!project_suggestions_user_id_fkey(id, display_name, username)")
            .eq("project_id", value: projectId)
            .eq("status", value: SuggestionStatus.approved.rawValue)
            .execute()
            .value
    }

    func invite(projectId: UUID, userId: UUID) async throws {
        try await client
            .rpc("rawdea_invite_contributor", params: [
                "p_project_id": projectId.uuidString,
                "p_user_id": userId.uuidString
            ])
            .execute()
    }

    func respond(projectId: UUID, accept: Bool) async throws {
        try await client
            .rpc("rawdea_respond_to_invite", params: InviteAnswer(
                projectId: projectId, accept: accept
            ))
            .execute()
    }

    func leave(projectId: UUID) async throws {
        try await client
            .rpc("rawdea_leave_project", params: ["p_project_id": projectId.uuidString])
            .execute()
    }

    func remove(projectId: UUID, userId: UUID, hidePosts: Bool) async throws {
        try await client
            .rpc("rawdea_remove_contributor", params: Removal(
                projectId: projectId, userId: userId, hidePosts: hidePosts
            ))
            .execute()
    }

    // MARK: - Owner over posts

    func setOwnerHidden(postId: UUID, hidden: Bool) async throws {
        try await client
            .rpc("rawdea_owner_set_post_hidden", params: OwnerHide(
                postId: postId, hidden: hidden
            ))
            .execute()
    }

    /// Pass nil to reopen the question.
    func setBestReplyAsOwner(postId: UUID, commentId: UUID?) async throws {
        try await client
            .rpc("rawdea_owner_set_best_reply", params: OwnerChoice(
                postId: postId, commentId: commentId
            ))
            .execute()
    }

    // MARK: - Held contributions

    func holdContribution(
        content: String,
        projectId: UUID,
        kind: PostKind
    ) async throws -> HoldReason {
        try await client
            .rpc("rawdea_hold_contribution", params: [
                "p_content": content,
                "p_project_id": projectId.uuidString,
                "p_kind": kind.rawValue
            ])
            .execute()
            .value
    }

    // MARK: - Credit

    /// Who a stage move would name.
    func creditPreview(projectId: UUID, stage: ProjectStage) async throws -> [String] {
        let rows: [CreditName] = try await client
            .rpc("rawdea_stage_credit_preview", params: [
                "p_project_id": projectId.uuidString,
                "p_stage": stage.rawValue
            ])
            .execute()
            .value
        return rows.map(\.username)
    }

    func fetchContributedTo(userId: UUID) async throws -> [ContributedProject] {
        try await client
            .rpc("rawdea_contributed_to", params: ["p_user_id": userId.uuidString])
            .execute()
            .value
    }
}

private struct MembershipProject: Decodable {
    let project: Project?
}

private struct CreditName: Decodable {
    let username: String
}

private struct InviteAnswer: Encodable {
    let projectId: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case projectId = "p_project_id"
        case accept = "p_accept"
    }
}

private struct Removal: Encodable {
    let projectId: UUID
    let userId: UUID
    let hidePosts: Bool

    enum CodingKeys: String, CodingKey {
        case projectId = "p_project_id"
        case userId = "p_user_id"
        case hidePosts = "p_hide_posts"
    }
}

private struct OwnerHide: Encodable {
    let postId: UUID
    let hidden: Bool

    enum CodingKeys: String, CodingKey {
        case postId = "p_post_id"
        case hidden = "p_hidden"
    }
}

private struct OwnerChoice: Encodable {
    let postId: UUID
    let commentId: UUID?

    enum CodingKeys: String, CodingKey {
        case postId = "p_post_id"
        case commentId = "p_comment_id"
    }

    // The function has no default, so nil is sent as null.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postId, forKey: .postId)
        try container.encode(commentId, forKey: .commentId)
    }
}
