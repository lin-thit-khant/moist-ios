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

    @State private var filter = RawdeaActivityFilter.all

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

    private var visibleGroups: [RawdeaActivityGroup] {
        RawdeaActivityGroup.grouping(
            viewModel.notifications.filter { $0.matches(filter) }
        )
    }

    // MARK: - Body

    var body: some View {

        List {

            filterChips

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

                RawdeaLoadingIndicator("Loading activity...")
                    .frame(maxWidth: .infinity)
                    .padding(
                        .vertical,
                        RawdeaSpacing.xl
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RawdeaPalette.canvas
                    )

            } else if viewModel.notifications.isEmpty &&
                        viewModel.heldNotices.isEmpty {

                RawdeaEmptyState(
                    symbol: "bell",
                    title: "Nothing new yet",
                    message:
                        "Answers, Project changes, likes and new followers appear here."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(
                    RawdeaPalette.canvas
                )

            } else {

                if filter == .all {
                    ForEach(viewModel.heldNotices) { notice in
                        heldRow(notice)
                    }
                }

                if visibleGroups.isEmpty &&
                    (filter != .all || viewModel.heldNotices.isEmpty) {

                    Text("Nothing here yet.")
                        .font(RawdeaTypography.secondary)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RawdeaSpacing.lg)
                        .listRowSeparator(.hidden)
                        .listRowBackground(RawdeaPalette.canvas)
                }

                ForEach(visibleGroups) { group in

                    activityRow(group)
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
        .toolbarTitleDisplayMode(.inlineLarge)

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

        .rawdeaRefreshable {

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

    // MARK: - Filters

    private var filterChips: some View {

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: RawdeaSpacing.xs) {
                ForEach(RawdeaActivityFilter.allCases, id: \.self) { item in
                    RawdeaChip(title: item.title, isSelected: filter == item) {
                        filter = item
                    }
                }
            }
            .padding(.horizontal, RawdeaSpacing.screenInset)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity filter")
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(RawdeaPalette.canvas)
    }

    // MARK: - Held post results

    private func heldRow(_ notice: HeldPostNotice) -> some View {

        RawdeaNote(title: notice.title, message: notice.message) {

            // The post itself, so two results can be told apart.
            RawdeaNoteDetail("“\(notice.content)”")
                .lineLimit(2)

            if notice.canAskAgain {
                RawdeaPillButton(
                    title: "Ask for a second look",
                    isWorking: viewModel.askingId == notice.id
                ) {
                    Task {
                        await viewModel.askForSecondLook(id: notice.id)
                    }
                }
                .disabled(viewModel.askingId != nil)
            }

            if notice.isSecondLookRequested {
                RawdeaNoteDetail("Second look requested.")
            }
        }
        .listRowInsets(
            EdgeInsets(
                top: RawdeaSpacing.xs,
                leading: RawdeaSpacing.screenInset,
                bottom: RawdeaSpacing.xs,
                trailing: RawdeaSpacing.screenInset
            )
        )
        .listRowSeparator(.hidden)
        .listRowBackground(RawdeaPalette.canvas)
    }

    // MARK: - Activity card

    private func activityRow(
        _ group: RawdeaActivityGroup
    ) -> some View {

        Button {

            Task {

                // The whole row is read together.
                for other in group.notifications.dropFirst() where !other.isRead {
                    _ = await viewModel.markAsRead(notificationId: other.id)
                }

                await openNotification(
                    group.latest
                )
            }

        } label: {

            RawdeaActivityCard(
                group: group,
                isOpening:
                    openingNotificationId ==
                    group.id
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
                top: RawdeaSpacing.xs,
                leading: RawdeaSpacing.screenInset,
                bottom: RawdeaSpacing.xs,
                trailing: RawdeaSpacing.screenInset
            )
        )
        .listRowSeparatorTint(RawdeaPalette.divider)
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

        case .suggestionsWaiting:

            return notification.projectId.map { .suggestions($0) }

        case .suggestionDeclined:

            return .mySuggestions(notification.projectId)

        case .projectFollow, .stageChange:

            guard let projectId =
                notification.projectId else {

                return nil
            }

            return .project(projectId)

        case .postLike, .postComment, .bestAnswer, .suggestionApproved:

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
