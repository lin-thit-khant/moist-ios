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
}
