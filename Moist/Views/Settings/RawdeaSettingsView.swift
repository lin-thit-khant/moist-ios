//
//  RawdeaSettingsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 24/11/2569 BE.
//

import Supabase
import SwiftUI

struct RawdeaSettingsView: View {

    @EnvironmentObject private var authViewModel:
        AuthViewModel

    @State private var showLogoutConfirmation = false
    @State private var logoutError: String?

    @State private var email: String?
    // Nil until loaded, so "None" is never a guess.
    @State private var blockedCount: Int?
    // Nil until checked. The server still authorizes every moderation call.
    @State private var isModerator: Bool?

    // Nil until loaded, so a toggle never shows a guess.
    @State private var preferences: NotificationPreferences?
    @State private var isSavingPreferences = false
    @State private var preferencesError: String?

    private let notificationService = NotificationService()

    private var appVersion: String {

        let version = Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleShortVersionString"
        ) as? String ?? "Unknown"

        if let build = Bundle.main.object(
            forInfoDictionaryKey:
                "CFBundleVersion"
        ) as? String {

            return "\(version) (\(build))"
        }

        return version
    }

    // MARK: - Body

    var body: some View {

        List {

            accountSection

            notificationsSection

            safetySection

            if isModerator == true {
                moderationSection
            }

            aboutSection

            signOutSection

        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)

        .disabled(authViewModel.isLoading)

        .task {

            email = try? await SupabaseManager
                .client.auth.session.user.email

            await loadPreferences()
        }
        .task {
            guard isModerator == nil else { return }
            do {
                isModerator = try await ModerationService().isModerator()
            } catch is CancellationError {
                return
            } catch {
                isModerator = false
            }
        }
        .onAppear {
            Task {
                blockedCount = try? await BlockService()
                    .fetchBlockedUsers()
                    .count
            }
        }

        // MARK: - Log out confirmation

        .confirmationDialog(
            "Sign out of Rawdea?",
            isPresented:
                $showLogoutConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Sign Out",
                role: .destructive
            ) {

                Task {

                    await logOut()
                }
            }

            Button(
                "Cancel",
                role: .cancel
            ) { }

        } message: {

            Text(
                "Your account and posts will remain available when you sign in again."
            )
        }

        // MARK: - Logout failure

        .alert(
            "Couldn't sign out",
            isPresented: Binding(
                get: {

                    logoutError != nil
                },
                set: { presented in

                    if !presented {

                        logoutError = nil
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {

                logoutError = nil
            }

        } message: {

            Text(logoutError ?? "")
        }
    }

    // MARK: - Safety and privacy

    private var safetySection: some View {

        Section("Privacy and safety") {

            NavigationLink {

                BlockedUsersView()

            } label: {

                detailRow(
                    title: "Blocked people",
                    detail: blockedCount.map {
                        $0 == 0 ? "None" : "\($0)"
                    }
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                SafetyCenterView()

            } label: {

                settingsRow(
                    title: "Report a problem"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Moderation

    private var moderationSection: some View {

        Section("Moderation") {

            NavigationLink {

                ModerationQueueView()

            } label: {

                detailRow(
                    title: "Reports",
                    detail: "Held posts and reports waiting"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                ModerationSafetyInboxView()

            } label: {

                detailRow(
                    title: "Safety inbox",
                    detail: "Appeals and problems from people"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Account

    private var accountSection: some View {

        Section("Account") {

            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                Text("Email")
                    .font(RawdeaTypography.body)
                    .foregroundStyle(RawdeaPalette.primaryText)
                Text(email ?? "—")
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, minHeight: RawdeaSpacing.minimumTouchTarget, alignment: .leading)
            .accessibilityElement(children: .combine)
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                ChangePasswordView()

            } label: {

                settingsRow(title: "Password")
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {

        Section("Notify me about") {

            if preferences != nil {

                preferenceToggle(
                    "Answers",
                    detail: "When someone answers your question or picks your answer",
                    value: \.answers
                )

                preferenceToggle(
                    "Stage changes",
                    detail: "When a Project you follow moves stage",
                    value: \.stageChanges
                )

                preferenceToggle(
                    "Likes",
                    detail: "When someone likes your post",
                    value: \.likes
                )

            } else if preferencesError == nil {

                RawdeaLoadingIndicator("Loading notification settings...")
                    .listRowBackground(RawdeaPalette.canvas)
            }

            if let preferencesError {

                VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                    RawdeaInlineError(message: preferencesError)

                    if preferences == nil {
                        Button("Retry") {
                            Task { await loadPreferences() }
                        }
                        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
                    }
                }
                .listRowBackground(RawdeaPalette.canvas)
            }
        }
    }

    private func preferenceToggle(
        _ title: String,
        detail: String,
        value: WritableKeyPath<NotificationPreferences, Bool>
    ) -> some View {

        Toggle(
            isOn: Binding(
                get: { preferences?[keyPath: value] ?? true },
                set: { isOn in
                    Task { await savePreference(value, isOn: isOn) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {
                Text(title)
                    .font(RawdeaTypography.body)
                    .foregroundStyle(RawdeaPalette.primaryText)
                Text(detail)
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(RawdeaPalette.accent)
        .disabled(isSavingPreferences)
        .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
        .listRowBackground(RawdeaPalette.canvas)
    }

    @MainActor
    private func loadPreferences() async {

        preferencesError = nil

        do {
            preferences = try await notificationService.fetchPreferences()
        } catch is CancellationError {
            return
        } catch {
            preferencesError = "Couldn't load notification settings."
        }
    }

    // The switch moves only after the server accepts the change.
    @MainActor
    private func savePreference(
        _ value: WritableKeyPath<NotificationPreferences, Bool>,
        isOn: Bool
    ) async {

        guard var changed = preferences, !isSavingPreferences else {
            return
        }

        changed[keyPath: value] = isOn
        isSavingPreferences = true
        preferencesError = nil

        defer { isSavingPreferences = false }

        do {
            try await notificationService.savePreferences(changed)
            preferences = changed
        } catch {
            preferencesError = "Couldn't save that setting. Try again."
        }
    }

    // MARK: - Sign out and delete

    private var signOutSection: some View {

        Section {

            Button(role: .destructive) {

                showLogoutConfirmation = true

            } label: {

                HStack(
                    spacing: RawdeaSpacing.sm
                ) {

                    settingsRow(
                        title: "Sign out",
                        isStrong: true
                    )

                    if authViewModel.isLoading {

                        ProgressView()
                            .accessibilityHidden(true)
                    }
                }
            }
            .disabled(authViewModel.isLoading)
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                DeleteAccountView()

            } label: {

                settingsRow(
                    title: "Delete account",
                    isDestructive: true
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
            .accessibilityHint(
                "Opens permanent account deletion settings"
            )
        }
    }

    // MARK: - About

    private var aboutSection: some View {

        Section("About") {

            LabeledContent {

                Text(appVersion)
                    .font(
                        RawdeaTypography.metadata
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )

            } label: {

                Text("Version")
                    .font(
                        RawdeaTypography.body
                    )
                    .foregroundStyle(
                        RawdeaPalette.primaryText
                    )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )

            if let url = configuredHTTPSURL(
                RawdeaPublicContact.privacyPolicyURL
            ) {

                Link(destination: url) {

                    settingsRow(
                        title: "Privacy Policy"
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else {

                NavigationLink {

                    SafetyInformationView()

                } label: {

                    settingsRow(
                        title: "Privacy Information"
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }
        }
    }

    // MARK: - Reusable settings row

    private func settingsRow(
        title: String,
        isDestructive: Bool = false,
        isStrong: Bool = false
    ) -> some View {

        Text(title)
            .font(isDestructive || isStrong
                ? RawdeaTypography.authorName
                : RawdeaTypography.body)
            .foregroundStyle(
                isDestructive
                ? RawdeaPalette.accent
                : RawdeaPalette.primaryText
            )
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                maxWidth: .infinity,
                minHeight: RawdeaSpacing.minimumTouchTarget,
                alignment: .leading
            )
            .contentShape(Rectangle())
    }

    private func detailRow(
        title: String,
        detail: String?
    ) -> some View {

        VStack(alignment: .leading, spacing: 0) {
            settingsRow(title: title)
            if let detail {
                Text(detail)
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - URL validation

    private func configuredHTTPSURL(
        _ value: String
    ) -> URL? {

        guard let url = URL(string: value),
              url.scheme == "https",
              url.host != nil else {

            return nil
        }

        return url
    }

    // MARK: - Log out

    @MainActor
    private func logOut() async {

        guard !authViewModel.isLoading else {
            return
        }

        logoutError = nil

        await authViewModel.signOut()

        if let error = authViewModel.errorMessage {

            logoutError = error
        }
    }
}
