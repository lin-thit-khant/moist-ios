//
//  ProjectService.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 7/11/2569 BE.
//

import Foundation
import Supabase

struct ProjectService {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }
    
    func fetchProjects(userId: UUID) async throws -> [Project] {
        try await client
            .from("projects")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func createProject(name: String) async throws -> Project {
        let user = try await client.auth.session.user
        
        return try await client
            .from("projects")
            .insert(NewProject(userId: user.id, name: name))
            .select()
            .single()
            .execute()
            .value
    }
}

private struct NewProject: Encodable {
    let userId: UUID
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
    }
}
