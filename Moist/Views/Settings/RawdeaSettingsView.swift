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

    @AppStorage(RawdeaAppearance.storageKey)
    private var selectedAppearance =
        RawdeaAppearance.system.rawValue

    @Environment(\.scenePhase)
    private var scenePhase

    @State private var canModerate = false

    @State private var isCheckingModerator = false
    @State private var moderatorCheckFailed = false

    @State private var showLogoutConfirmation = false
    @State private var logoutError: String?

    @State private var email: String?

    // Nil until loaded, so a toggle never shows a guess.
    @State private var preferences: NotificationPreferences?
    @State private var isSavingPreferences = false
    @State private var preferencesError: String?

    private let notificationService = NotificationService()

    private var appearance: RawdeaAppearance {

        RawdeaAppearance(
            rawValue: selectedAppearance
        ) ?? .system
    }

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

            preferencesSection

            safetySection

            moderationSection

            aboutSection

            signOutSection

            #if DEBUG

            Section("Developer Tools") {

                NavigationLink {

                    RawdeaDesignPreviewView()

                } label: {

                    settingsRow(
                        title: "Design System Preview",
                        symbol: "paintpalette"
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }

            #endif
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

        // MARK: - Moderator authorization

        .task {

            await checkModeratorAccess()
        }

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {

                await checkModeratorAccess()
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

    // MARK: - Preferences

    private var preferencesSection: some View {

        Section("Display") {

            NavigationLink {

                AppearanceSettingsView()

            } label: {

                HStack(
                    spacing: RawdeaSpacing.sm
                ) {

                    settingsRow(
                        title: "Appearance",
                        symbol:
                            "circle.lefthalf.filled"
                    )

                    Text(appearance.title)
                        .font(
                            RawdeaTypography.metadata
                        )
                        .foregroundStyle(
                            RawdeaPalette.secondaryText
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                }
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Safety and privacy

    private var safetySection: some View {

        Section("Privacy and safety") {

            NavigationLink {

                BlockedUsersView()

            } label: {

                settingsRow(
                    title: "Blocked people",
                    symbol:
                        "person.crop.circle.badge.xmark"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                SafetyCenterView()

            } label: {

                settingsRow(
                    title: "Report a problem",
                    symbol: "shield"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )

            NavigationLink {

                SafetyInformationView()

            } label: {

                settingsRow(
                    title: "Community guidelines",
                    symbol: "book"
                )
            }
            .listRowBackground(
                RawdeaPalette.canvas
            )
        }
    }

    // MARK: - Moderator-only tools

    @ViewBuilder
    private var moderationSection: some View {

        if canModerate {

            Section("Moderation") {

                NavigationLink {

                    ModerationQueueView()

                } label: {

                    settingsRow(
                        title: "Moderation Queue",
                        symbol: "checkmark.shield"
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )

                NavigationLink {

                    ModerationSafetyInboxView()

                } label: {

                    settingsRow(
                        title: "Safety Support Inbox",
                        symbol: "tray.full"
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }

        } else if moderatorCheckFailed {

            Section {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInlineError(
                        message:
                            "Couldn't verify additional account permissions."
                    )

                    Button("Retry") {

                        Task {

                            await checkModeratorAccess()
                        }
                    }
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }
        }
    }

    // MARK: - Account

    private var accountSection: some View {

        Section("Account") {

            LabeledContent {

                Text(email ?? "—")
                    .font(RawdeaTypography.metadata)
                    .foregroundStyle(RawdeaPalette.secondaryText)
                    .textSelection(.enabled)

            } label: {

                Text("Email")
                    .font(RawdeaTypography.body)
                    .foregroundStyle(RawdeaPalette.primaryText)
            }
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
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
                        symbol:
                            "rectangle.portrait.and.arrow.right"
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
                    symbol:
                        "person.crop.circle.badge.minus",
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
                        title: "Privacy Policy",
                        symbol: "hand.raised"
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
                        title: "Privacy Information",
                        symbol: "hand.raised"
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
        symbol: String,
        isDestructive: Bool = false
    ) -> some View {

        HStack(
            spacing: RawdeaSpacing.sm
        ) {

            Image(systemName: symbol)
                .font(.system(.body))
                .foregroundStyle(
                    isDestructive
                    ? RawdeaPalette.danger
                    : RawdeaPalette.secondaryText
                )
                .frame(minWidth: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(RawdeaTypography.body)
                .foregroundStyle(
                    isDestructive
                    ? RawdeaPalette.danger
                    : RawdeaPalette.primaryText
                )
                .multilineTextAlignment(.leading)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer(minLength: 0)
        }
        .frame(
            minHeight:
                RawdeaSpacing.minimumTouchTarget
        )
        .contentShape(Rectangle())
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

    // MARK: - Authorization

    @MainActor
    private func checkModeratorAccess() async {

        guard !isCheckingModerator else {
            return
        }

        isCheckingModerator = true

        // Fail closed while authorization
        // is being checked.

        canModerate = false
        moderatorCheckFailed = false

        defer {

            isCheckingModerator = false
        }

        do {

            let allowed = try await ModerationService()
                .isModerator()

            try Task.checkCancellation()

            canModerate = allowed

        } catch is CancellationError {

            return

        } catch {

            guard !Task.isCancelled else {
                return
            }

            canModerate = false
            moderatorCheckFailed = true
        }
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
