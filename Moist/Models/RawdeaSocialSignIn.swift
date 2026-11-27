//
//  RawdeaSocialSignIn.swift
//  Rawdea
//

/// Which third-party sign-in choices are ready to use.
/// A choice that is not ready explains that when tapped.
enum RawdeaSocialSignIn {

    /// Turn on after `[auth.external.google]` is configured
    /// in Supabase with a Google client ID and secret.
    static let isGoogleReady = false

    static func notReadyMessage(_ provider: String) -> String {
        "\(provider) sign-in isn't set up yet. Continue with email for now."
    }
}
