//
//  ProfileService.swift
//  Moist
//
//  Created by Lin Thit Khant on 1/11/2569 BE.
//

import Foundation
import Supabase

struct ProfileService {
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.client) {
        self.client = client
    }
    
    func fetchCurrentProfile() async throws -> Profile {
        let user = try await client.auth.session.user
        
        return try await client
            .from("profiles")
            .select()
            .eq("id", value: user.id)
            .single()
            .execute()
            .value
    }
    
    func updateCurrentProfiel(displayName: String, bio: String) async throws -> Profile {
        let user = try await client.auth.session.user
        
        let updatedProfile = ProfileUpdate(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: Date()
        )
        
        try await client
            .from("profiles")
            .update(updatedProfile)
            .eq("id", value: user.id)
            .execute()
        
        return try await fetchCurrentProfile()
    }
}

private struct ProfileUpdate: Encodable {
    let displayName: String
    let bio: String
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
        case updatedAt = "updated_at"
    }
}
