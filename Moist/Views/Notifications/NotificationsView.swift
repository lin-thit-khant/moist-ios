//
//  NotificationsView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 16/11/2569 BE.
//

import SwiftUI

struct NotificationsView: View {

    @ObservedObject var viewModel:
        NotificationsViewModel

    @State private var openingNotificationId: UUID?

    @State private var navigationError: String?

    @Environment(\.rawdeaOpenPostRoute)
    private var openPostRoute

    @Environment(\.scenePhase)
    private var scenePhase

    private var isBusy: Bool {

        openingNotificationId != nil ||
        viewModel.isLoading ||
        viewModel.isMarkingAll ||
        !viewModel.updatingIds.isEmpty
    }

    private var hasUnreadNotifications: Bool {

        viewModel.unreadCount > 0 ||
        viewModel.notifications.contains {
            !$0.isRead
        }
    }

    // MARK: - Body

    var body: some View {

        List {

            if let error = viewModel.errorMessage,
               !viewModel.hasLoaded {

                RawdeaEmptyState(
                    symbol: "exclamationmark.circle",
                    title: "Couldn't load activity",
                    message: error,
                    actionTitle: "Try Again"
                ) {

                    Task {

                        await viewModel.loadNotifications()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else if !viewModel.hasLoaded {

                ProgressView("Loading activity...")
                    .frame(maxWidth: .infinity)
                    .padding(
                        .vertical,
                        RawdeaSpacing.xl
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

            } else if viewModel.notifications.isEmpty {

                RawdeaEmptyState(
                    symbol: "bell",
                    title: "Nothing new yet",
                    message:
                        "Likes, comments, and new followers will appear here."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else {

                activitySummary

                ForEach(
                    viewModel.notifications
                ) { notification in

                    activityRow(notification)
                }

                if viewModel.notifications.count >= 100 {

                    Text(
                        "Showing the 100 most recent notifications."
                    )
                    .font(
                        RawdeaTypography.caption
                    )
                    .foregroundStyle(
                        RawdeaPalette.secondaryText
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )
                }
            }

            if viewModel.hasLoaded,
               let error = viewModel.errorMessage {

                VStack(
                    alignment: .leading,
                    spacing: RawdeaSpacing.xs
                ) {

                    RawdeaInlineError(
                        message:
                            "Couldn't refresh activity. \(error)"
                    )

                    Button("Try Again") {

                        Task {

                            await viewModel.loadNotifications()
                        }
                    }
                    .frame(
                        minHeight:
                            RawdeaSpacing.minimumTouchTarget
                    )
                }
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Mark all read

        .toolbar {

            // Only offered when there is something
            // to mark, so an empty Activity screen
            // stays quiet.
            if hasUnreadNotifications || viewModel.isMarkingAll {

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
                    isBusy ||
                    !hasUnreadNotifications
                )
                .accessibilityLabel(
                    viewModel.isMarkingAll
                    ? "Marking notifications as read"
                    : "Mark all notifications as read"
                )
            }
            }
        }

        // Preserve visibility revalidation.

        .onAppear {

            Task {

                await viewModel
                    .reloadVisibleNotifications()
            }
        }

        .onChange(of: scenePhase) { _, phase in

            guard phase == .active else {
                return
            }

            Task {

                await viewModel
                    .reloadVisibleNotifications()
            }
        }

        .refreshable {

            guard openingNotificationId == nil else {
                return
            }

            await viewModel.loadNotifications()
        }

        // MARK: - Errors

        .alert(
            "Couldn't complete action",
            isPresented: Binding(
                get: {

                    navigationError != nil ||
                    viewModel.actionErrorMessage != nil
                },
                set: { presented in

                    if !presented {

                        clearErrors()
                    }
                }
            )
        ) {

            Button("OK", role: .cancel) {

                clearErrors()
            }

        } message: {

            Text(
                navigationError
                ?? viewModel.actionErrorMessage
                ?? ""
            )
        }
    }

    // MARK: - Activity summary

    private var activitySummary: some View {

        VStack(
            alignment: .leading,
            spacing: RawdeaSpacing.xxs
        ) {

            Text("Recent activity")
                .font(
                    RawdeaTypography.sectionTitle
                )
                .foregroundStyle(
                    RawdeaPalette.primaryText
                )
                .accessibilityAddTraits(.isHeader)

            Text(
                "\(viewModel.unreadCount) unread"
            )
            .font(
                RawdeaTypography.metadata
            )
            .foregroundStyle(
                RawdeaPalette.secondaryText
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .padding(
            .vertical,
            RawdeaSpacing.xs
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RawdeaPalette.canvas
        )
    }

    // MARK: - Activity card

    private func activityRow(
        _ notification: RawdeaNotification
    ) -> some View {

        Button {

            Task {

                await openNotification(
                    notification
                )
            }

        } label: {

            RawdeaActivityCard(
                notification: notification,
                isOpening:
                    openingNotificationId ==
                    notification.id
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityHint(
            "Opens the related activity"
        )
        .listRowInsets(
            EdgeInsets(
                top: RawdeaSpacing.xxs,
                leading: RawdeaSpacing.screenInset,
                bottom: RawdeaSpacing.xxs,
                trailing: RawdeaSpacing.screenInset
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(
            RawdeaPalette.canvas
        )
    }

    // MARK: - Open notification

    @MainActor
    private func openNotification(
        _ notification: RawdeaNotification
    ) async {

        guard !isBusy else {
            return
        }

        openingNotificationId = notification.id

        navigationError = nil

        defer {

            openingNotificationId = nil
        }

        let didRead = await viewModel.markAsRead(
            notificationId: notification.id
        )

        guard didRead else {
            // Keep the user on Activity if the
            // read mutation fails.
            return
        }

        guard let route = destination(
            for: notification
        ) else {

            navigationError =
                "This activity no longer has an available destination."

            return
        }

        guard let openPostRoute else {

            navigationError =
                "The activity destination couldn't be opened."

            return
        }

        // Use the same value-based router as
        // Home, Explore, Profile and Projects.

        openPostRoute(route)
    }

    // MARK: - Destination mapping

    private func destination(
        for notification: RawdeaNotification
    ) -> RawdeaPostRoute? {

        switch notification.kind {

        case .userFollow:

            return .author(
                notification.actorId
            )

        case .projectFollow:

            guard let projectId =
                notification.projectId else {

                return nil
            }

            return .project(projectId)

        case .postLike, .postComment:

            guard let postId =
                notification.postId else {

                return nil
            }

            return .discussion(postId)
        }
    }

    private func clearErrors() {

        navigationError = nil

        viewModel.clearActionError()
    }
}
