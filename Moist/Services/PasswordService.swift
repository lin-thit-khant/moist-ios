//
//  PasswordService.swift
//  Rawdea
//

import Foundation
import Supabase

struct PasswordService {

    enum Failure: Error {
        case wrongCurrentPassword
    }

    private let client: SupabaseClient
    private let verifier: SupabaseClient

    init(
        client: SupabaseClient = SupabaseManager.client,
        verifier: SupabaseClient = SupabaseManager.verificationClient()
    ) {
        self.client = client
        self.verifier = verifier
    }

    /// An unlocked phone alone must not be enough to take over an
    /// account, so the current password is checked first, on a
    /// separate client that leaves the app's session untouched.
    func changePassword(current: String, new: String) async throws {

        guard let email = try await client.auth.session.user.email else {
            throw Failure.wrongCurrentPassword
        }

        do {
            _ = try await verifier.auth.signIn(email: email, password: current)
        } catch let error as AuthError where error.errorCode == .invalidCredentials {
            throw Failure.wrongCurrentPassword
        }

        // Only this temporary session is signed out.
        try? await verifier.auth.signOut(scope: .local)

        try await client.auth.update(user: UserAttributes(password: new))
    }
}
