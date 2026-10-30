//
//  SupabaseManager.swift
//  Moist
//
//  Created by Lin Thit Khant on 30/10/2569 BE.
//

import Foundation
import Supabase

enum SupabaseManager {
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://swfkgdozbjcdpjfqzjqe.supabase.co")!,
        supabaseKey: "sb_publishable_0UqTJ11QINwZ58e0NMjS9Q_xLEaAg8c"
    )
}
