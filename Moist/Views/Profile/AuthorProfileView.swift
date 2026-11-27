//
//  AuthorProfileView.swift
//  Moist
//
//  Created by Lin Thit Khant on 3/11/2569 BE.
//


import SwiftUI

struct AuthorProfileView: View {

    let userId: UUID

    // MARK: - Existing ViewModels

    @StateObject private var viewModel =
        ProfileViewModel()

    @StateObject private var followViewModel =
        UserFollowViewModel()

    // MARK: - Blocking

    @StateObject private var blockViewModel =
        UserBlockViewModel()

    @State private var showBlockConfirmation = false
    @State private var reportTarget: ReportTarget?

    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Body

    var body: some View {

        Group {

            // Check the relationship before
            // displaying profile information.

            if !blockViewModel.hasChecked {

                if let error = blockViewModel.errorMessage {

                    VStack(spacing: 16) {

                        ContentUnavailableView(
                            "Couldn't Check Account",
                            systemImage: "exclamationmark.shield",
                            description: Text(error)
                        )

                        Button("Try Again") {

                            Task {
                                await loadAvailableProfile()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()

                } else {

                    RawdeaLoadingIndicator("Checking account...")
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }

            // MARK: - Blocked State

            } else if blockViewModel.isBlocked {

                blockedAccountContent

            // MARK: - Existing Loading State

            } else if viewModel.isLoading &&
                      viewModel.profile == nil {

                RawdeaLoadingIndicator("Loading profile...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )

            // MARK: - Existing Error State

            } else if let error = viewModel.errorMessage,
                      viewModel.profile == nil {

                VStack(spacing: 16) {

                    ContentUnavailableView(
                        "Couldn't Load This Profile",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )

                    Button("Try Again") {

                        Task {
                            await loadAvailableProfile()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            // MARK: - Existing Profile

            } else if let profile = viewModel.profile {

                ScrollView {

                    VStack(spacing: 20) {

                        ProfileContentView(
                            profile: profile
                        )

                        // MARK: - Following

                        RawdeaUserFollowSection(
                            userId: userId,
                            viewModel: followViewModel,
                            isInteractionBlocked:
                                blockViewModel.isUpdating
                        )

                        RawdeaShareProfileLink(profile: profile)

                        // Preserve existing public
                        // posts and Projects.

                        PublicProfileSectionsView(
                            userId: userId
                        )
                    }
                    .padding(
                        .horizontal,
                        RawdeaSpacing.screenInset
                    )
                    .padding(
                        .vertical,
                        RawdeaSpacing.lg
                    )
                }

            } else {

                RawdeaLoadingIndicator("Preparing profile...")
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
            }
        }
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Block Menu

        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                if blockViewModel.hasChecked &&
                   !blockViewModel.isBlocked &&
                   viewModel.profile != nil &&
                   followViewModel.hasLoaded &&
                   !followViewModel.isOwnProfile {

                    Menu {
                        
                        Button {

                            reportTarget = .account(userId)

                        } label: {

                            Label(
                                "Report Account",
                                systemImage: "flag"
                            )
                        }

                        Button(
                            "Block Account",
                            systemImage: "person.crop.circle.badge.xmark",
                            role: .destructive
                        ) {

                            showBlockConfirmation = true
                        }

                    } label: {

                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(blockViewModel.isUpdating)
                }
            }
        }
        .sheet(item: $reportTarget) { target in
            ReportContentView(target: target)
        }

        // MARK: - Confirm Block

        .confirmationDialog(
            "Block this account?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Block Account",
                role: .destructive
            ) {

                Task {

                    await blockViewModel.block(
                        userId: userId
                    )
                }
            }

            Button("Cancel", role: .cancel) { }

        } message: {

            Text(
                "You will stop following each other. Your profiles, posts, and Projects will no longer be accessible to one another."
            )
        }

        // MARK: - Block Action Error

        .alert(
            "Couldn't Change Block",
            isPresented: Binding(
                get: {
                    blockViewModel.hasChecked &&
                    blockViewModel.errorMessage != nil
                },
                set: { isPresented in

                    if !isPresented {
                        blockViewModel.clearError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {
                blockViewModel.clearError()
            }

        } message: {

            Text(blockViewModel.errorMessage ?? "")
        }

        
        .onAppear {
            Task {
                await loadAvailableProfile()
            }
        }
        .onChange(of: userId) { _, _ in
            Task {
                await loadAvailableProfile()
            }
        }
        
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await loadAvailableProfile()
            }
        }
        
    }

    // MARK: - Blocked Account UI

    private var blockedAccountContent: some View {

        VStack(spacing: 16) {

            Image(
                systemName: "person.crop.circle.badge.xmark"
            )
            .font(.largeTitle)
            .foregroundStyle(.secondary)

            Text("Account Blocked")
                .font(.headline)

            Text(
                "You cannot view or interact with this account while it is blocked."
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button {

                Task {

                    let succeeded = await blockViewModel.unblock(
                        userId: userId
                    )

                    if succeeded {

                        await viewModel.loadProfile(
                            userId: userId
                        )

                        await followViewModel.load(
                            userId: userId
                        )
                    }
                }

            } label: {

                if blockViewModel.isUpdating {

                    ProgressView()

                } else {

                    Text("Unblock Account")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(blockViewModel.isUpdating)
        }
        .padding()
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }

    // MARK: - Load Available Profile

    @MainActor
    private func loadAvailableProfile() async {

        // Check blocking first.

        await blockViewModel.loadStatus(
            userId: userId
        )

        // Do not fetch a profile when
        // its block status is unknown
        // or it is blocked.

        guard blockViewModel.hasChecked,
              !blockViewModel.isBlocked else {
            return
        }

        // Keep existing data loading.

        await viewModel.loadProfile(
            userId: userId
        )

        if viewModel.profile != nil {

            await followViewModel.load(
                userId: userId
            )
        }
    }
}
