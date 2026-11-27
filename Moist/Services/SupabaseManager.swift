//
//  SupabaseManager.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import Foundation
import Supabase

enum SupabaseManager {
    private static func requiredConfigValue(forKey key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty,
              !value.hasPrefix("$(") else {
            fatalError("Missing or invalid build setting: \(key)")
        }
        return value
    }
    
    static let client = SupabaseClient(
        supabaseURL: URL(string: requiredConfigValue(forKey: "SUPABASE_URL"))!,
        supabaseKey: requiredConfigValue(forKey: "SUPABASE_KEY")
    )
    
    /// A client whose session is never saved, for checking a password.
    static func verificationClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: requiredConfigValue(forKey: "SUPABASE_URL"))!,
            supabaseKey: requiredConfigValue(forKey: "SUPABASE_KEY"),
            options: SupabaseClientOptions(
                auth: .init(storage: RawdeaMemoryAuthStorage())
            )
        )
    }
    
    static func debugConfiguration() {
        print("=== MOIST SUPABASE DEBUG ===")

        print(
            "Supabase URL:",
            requiredConfigValue(forKey: "SUPABASE_URL")
        )

        print(
            "Environment:",
            Bundle.main.object(
                forInfoDictionaryKey: "SUPABASE_ENV"
            ) ?? "Not configured"
        )
    }
}


/// Keeps a session in memory only.
final class RawdeaMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {

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
