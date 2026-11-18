//
//  BlockedUsersView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 18/11/2569 BE.
//


import SwiftUI

struct BlockedUsersView: View {

    @StateObject private var viewModel =
        BlockedUsersViewModel()

    @State private var pendingUnblock: BlockedUser?

    var body: some View {

        List {

            // MARK: - Loading

            if viewModel.isLoading && !viewModel.hasLoaded {

                ProgressView("Loading blocked accounts...")
                    .frame(maxWidth: .infinity)

            // MARK: - Empty State

            } else if viewModel.users.isEmpty &&
                      viewModel.hasLoaded {

                ContentUnavailableView(
                    "No Blocked Accounts",
                    systemImage: "person.crop.circle",
                    description: Text(
                        "Accounts you block will appear here."
                    )
                )

            // MARK: - Blocked Accounts

            } else {

                ForEach(viewModel.users) { user in

                    HStack(spacing: 12) {

                        Image(
                            systemName: "person.crop.circle.fill"
                        )
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)

                        VStack(
                            alignment: .leading,
                            spacing: 4
                        ) {

                            Text(user.displayName)
                                .fontWeight(.semibold)

                            Text("@\(user.blockedUsername)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if viewModel.unblockingUserId == user.id {

                            ProgressView()

                        } else {

                            Button("Unblock") {

                                pendingUnblock = user
                            }
                            .buttonStyle(.bordered)
                            .disabled(
                                viewModel.unblockingUserId != nil
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            // MARK: - Errors

            if let error = viewModel.errorMessage {

                Section {

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button("Try Again") {

                        Task {
                            await viewModel.loadUsers()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)

        .navigationTitle("Blocked Accounts")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Initial Load

        .task {
            await viewModel.loadUsers()
        }

        // MARK: - Pull to Refresh

        .refreshable {
            await viewModel.loadUsers()
        }

        // MARK: - Unblock Confirmation

        .confirmationDialog(
            "Unblock this account?",
            isPresented: Binding(
                get: {
                    pendingUnblock != nil
                },
                set: { isPresented in
                    if !isPresented {
                        pendingUnblock = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {

            Button("Unblock") {

                guard let user = pendingUnblock else {
                    return
                }

                pendingUnblock = nil

                Task {

                    await viewModel.unblockUser(
                        userId: user.id
                    )
                }
            }

            Button("Cancel", role: .cancel) {
                pendingUnblock = nil
            }

        } message: {

            Text(
                "Unblocking will not automatically restore your previous follows."
            )
        }
    }
}
