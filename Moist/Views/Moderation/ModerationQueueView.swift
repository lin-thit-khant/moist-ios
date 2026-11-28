//
//  ModerationQueueView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import SwiftUI

struct ModerationQueueView: View {

    @StateObject private var viewModel =
        ModerationQueueViewModel()

    @StateObject private var heldViewModel =
        HeldQueueViewModel()

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {

        Group {

            if viewModel.isAuthorized == true {

                authorizedContent

            } else if viewModel.isAuthorized == false {

                ContentUnavailableView(
                    "Access Denied",
                    systemImage: "lock.shield",
                    description: Text(
                        "This account is not authorized to review reports."
                    )
                )

            } else if let error = viewModel.errorMessage {

                VStack(spacing: 16) {

                    ContentUnavailableView(
                        "Couldn't Check Access",
                        systemImage: "exclamationmark.shield",
                        description: Text(error)
                    )

                    Button("Try Again") {

                        Task {
                            await viewModel.retryAuthorization()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

            } else {

                RawdeaLoadingIndicator("Checking moderation access...")
            }
        }
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: viewModel.selectedStatus) {
            await viewModel.prepare()
        }

        .task(id: viewModel.isAuthorized) {
            guard viewModel.isAuthorized == true else { return }
            await heldViewModel.load()
        }

        .onAppear {

            guard viewModel.isAuthorized == true else {
                return
            }

            Task {
                await viewModel.reload()
            }
        }
    }

    // MARK: - Authorized Queue

    private var authorizedContent: some View {

        List {

            heldSection

            Group {

                Section {

                    Picker(
                        "Review Status",
                        selection: $viewModel.selectedStatus
                    ) {

                        ForEach(ModerationStatus.allCases) { status in

                            Text(status.title)
                                .tag(status)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(
                        viewModel.isLoading ||
                        viewModel.isLoadingMore
                    )

                } header: {

                    Text("Report Queue")

                } footer: {

                    Text(
                        "Pending reports are displayed oldest first."
                    )
                }

                if viewModel.isLoading {

                    Section {

                        RawdeaLoadingIndicator("Loading reports...")
                            .frame(maxWidth: .infinity)
                    }

                } else if viewModel.reports.isEmpty &&
                          viewModel.errorMessage == nil {

                    Section {

                        ContentUnavailableView(
                            "No Reports",
                            systemImage: "checkmark.shield",
                            description: Text(
                                "There are no reports with this status."
                            )
                        )
                    }

                } else {

                    Section("Reports") {

                        ForEach(viewModel.reports) { report in

                            NavigationLink {

                                ModerationReportDetailView(
                                    reportId: report.id
                                )

                            } label: {

                                reportRow(report)
                            }
                        }

                        if viewModel.hasMore {

                            HStack {

                                Spacer()

                                if viewModel.isLoadingMore {

                                    RawdeaLoadingIndicator("Loading more...")

                                } else {

                                    Button("Load More Reports") {

                                        Task {
                                            await viewModel.loadMore()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Spacer()
                            }
                        }
                    }
                }

                if let error = viewModel.errorMessage {

                    Section {

                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)

                        Button("Retry") {

                            Task {
                                await viewModel.reload()
                            }
                        }
                    }
                }
            }
            .listRowBackground(RawdeaPalette.canvas)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas.ignoresSafeArea())

        .rawdeaRefreshable {
            await heldViewModel.load()
            await viewModel.reload()
        }
    }

    // MARK: - Held Posts

    private var heldSection: some View {

        Section("Held posts") {

            if let error = heldViewModel.errorMessage {

                RawdeaInlineError(message: error)

                Button("Try Again") {
                    Task { await heldViewModel.load() }
                }
                .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            }

            if !heldViewModel.hasLoaded {

                if heldViewModel.errorMessage == nil {
                    RawdeaLoadingIndicator("Loading held posts...")
                        .frame(maxWidth: .infinity)
                }

            } else if heldViewModel.items.isEmpty {

                Text("Queue is empty. Held posts appear here with the reason.")
                    .font(RawdeaTypography.secondary)
                    .foregroundStyle(RawdeaPalette.secondaryText)

            } else {

                ForEach(heldViewModel.items) { item in
                    heldRow(item)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listRowBackground(RawdeaPalette.canvas)
    }

    private func heldRow(_ item: HeldQueueItem) -> some View {

        let buttons = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: RawdeaSpacing.xs))
            : AnyLayout(HStackLayout(spacing: RawdeaSpacing.xs))

        return RawdeaNote(
            title: "@\(item.username) · \(item.accountAge())",
            message: item.content
        ) {

            RawdeaNoteDetail("Held because: \(item.reason.text)")

            if item.appealed {
                RawdeaNoteDetail("Second look requested.")
            }

            buttons {
                RawdeaPillButton(title: "Approve", isPrimary: true) {
                    Task { await heldViewModel.decide(item, approve: true) }
                }
                RawdeaPillButton(title: "Remove") {
                    Task { await heldViewModel.decide(item, approve: false) }
                }
                if heldViewModel.decidingId == item.id {
                    ProgressView()
                }
            }
            .disabled(heldViewModel.decidingId != nil)
        }
    }

    // MARK: - Report Row

    private func reportRow(
        _ report: ModerationQueueItem
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            // Stacked at large text so words never break.
            let header = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading))
                : AnyLayout(HStackLayout())

            header {

                Label(
                    report.targetTitle,
                    systemImage: "flag"
                )
                .font(.subheadline)
                .fontWeight(.semibold)

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }

                Text(report.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(report.reasonTitle)
                .font(.subheadline)

            Text(
                "@\(report.evidenceUsername ?? "unknown")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            if report.status == "reviewing" {

                Label(
                    "Under review",
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 6)
    }
}
