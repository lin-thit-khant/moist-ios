//
//  NotificationsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//


import SwiftUI

// MARK: - Navigation Destinations

private enum NotificationDestination: Hashable {

    case profile(UUID)
    case project(UUID)
    case post(UUID)
}

struct NotificationsView: View {

    @ObservedObject var viewModel: NotificationsViewModel

    @State private var selectedDestination:
        NotificationDestination?
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {

        List {

            // MARK: - Initial Loading

            if viewModel.isLoading &&
               !viewModel.hasLoaded {

                HStack(spacing: 12) {

                    ProgressView()

                    Text("Loading notifications...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowSeparator(.hidden)

            // MARK: - Initial Error

            } else if let error = viewModel.errorMessage,
                      !viewModel.hasLoaded {

                VStack(spacing: 12) {

                    Image(systemName: "exclamationmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Couldn't load notifications")
                        .font(.headline)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {

                        Task {
                            await viewModel.loadNotifications()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowSeparator(.hidden)

            // MARK: - Before First Load

            } else if !viewModel.hasLoaded {

                ProgressView("Loading notifications...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .listRowSeparator(.hidden)

            // MARK: - Empty State

            } else if viewModel.notifications.isEmpty {

                ContentUnavailableView(
                    "No Notifications Yet",
                    systemImage: "bell",
                    description: Text(
                        "Activity involving your account, Projects, and posts will appear here."
                    )
                )
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)

            // MARK: - Notifications

            } else {

                ForEach(viewModel.notifications) {
                    notification in

                    Button {

                        Task {

                            // Mark read before navigating.

                            await viewModel.markAsRead(
                                notificationId: notification.id
                            )

                            if let destination = destination(
                                for: notification
                            ) {
                                selectedDestination = destination
                            }
                        }

                    } label: {

                        notificationRow(notification)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }

                if viewModel.notifications.count == 100 {

                    Text(
                        "Showing the 100 most recent notifications."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                }
            }

            // MARK: - Refresh Error

            if viewModel.hasLoaded,
               let error = viewModel.errorMessage {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Couldn't refresh notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Try Again") {

                        Task {
                            await viewModel.loadNotifications()
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)

        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Toolbar

        .toolbar {

            ToolbarItem(
                placement: .topBarTrailing
            ) {

                Button {

                    Task {
                        await viewModel.markAllAsRead()
                    }

                } label: {

                    if viewModel.isMarkingAll {

                        ProgressView()

                    } else {

                        Text("Mark All Read")
                    }
                }
                .disabled(
                    viewModel.unreadCount == 0 ||
                    viewModel.isLoading ||
                    viewModel.isMarkingAll ||
                    !viewModel.updatingIds.isEmpty
                )
            }
        }
        
        .onAppear {

            Task {

                await viewModel.reloadVisibleNotifications()
            }
        }
        
        
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await viewModel.reloadVisibleNotifications()
            }
        }


        // MARK: - Pull to Refresh

        .refreshable {
            await viewModel.loadNotifications()
        }

        // MARK: - Destination Routing

        .navigationDestination(
            item: $selectedDestination
        ) { destination in

            switch destination {

            case .profile(let userId):

                AuthorProfileView(userId: userId)

            case .project(let projectId):

                ProjectRouteView(projectId: projectId)

            case .post(let postId):

                PostDetailView(postId: postId)
            }
        }

        // MARK: - Action Errors

        .alert(
            "Couldn't update notification",
            isPresented: Binding(
                get: {
                    viewModel.actionErrorMessage != nil
                },
                set: { isPresented in

                    if !isPresented {
                        viewModel.clearActionError()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {

                viewModel.clearActionError()
            }

        } message: {

            Text(
                viewModel.actionErrorMessage ?? ""
            )
        }
    }

    // MARK: - Notification Row

    private func notificationRow(
        _ notification: RawdeaNotification
    ) -> some View {

        HStack(alignment: .center, spacing: 12) {

            Image(
                systemName: notification.kind.systemImage
            )
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .background(
                .thinMaterial,
                in: Circle()
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(notification.message)
                    .font(.subheadline)
                    .fontWeight(
                        notification.isRead
                        ? .regular
                        : .semibold
                    )
                    .foregroundStyle(.primary)

                Text(
                    notification.createdAt,
                    style: .relative
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if !notification.isRead {

                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Unread")
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Notification Destination

    private func destination(
        for notification: RawdeaNotification
    ) -> NotificationDestination? {

        switch notification.kind {

        case .userFollow:

            return .profile(notification.actorId)

        case .projectFollow:

            guard let projectId = notification.projectId else {
                return nil
            }

            return .project(projectId)

        case .postLike, .postComment:

            guard let postId = notification.postId else {
                return nil
            }

            return .post(postId)
        }
    }
}
