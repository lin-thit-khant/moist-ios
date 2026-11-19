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

                ProgressView("Checking moderation access...")
            }
        }
        .navigationTitle("Moderation")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: viewModel.selectedStatus) {
            await viewModel.prepare()
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
                .pickerStyle(.segmented)
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

                    ProgressView("Loading reports...")
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

                                ProgressView("Loading more...")

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
        .listStyle(.insetGrouped)

        .refreshable {
            await viewModel.reload()
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

            HStack {

                Label(
                    report.targetTitle,
                    systemImage: "flag"
                )
                .font(.subheadline)
                .fontWeight(.semibold)

                Spacer()

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
