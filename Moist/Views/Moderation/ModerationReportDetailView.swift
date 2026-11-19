//
//  ModerationReportDetailView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import SwiftUI

struct ModerationReportDetailView: View {

    let reportId: UUID

    @StateObject private var viewModel =
        ModerationDetailViewModel()

    @State private var reviewNote = ""
    @State private var showDismissConfirmation = false

    private var cleanedNote: String {
        reviewNote.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var isNoteValid: Bool {
        (5...1000).contains(cleanedNote.count)
    }

    var body: some View {

        Group {

            if let report = viewModel.report {

                reportContent(report)

            } else if let error = viewModel.errorMessage {

                VStack(spacing: 16) {

                    ContentUnavailableView(
                        "Couldn't Load Report",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )

                    Button("Retry") {
                        Task {
                            await viewModel.load(
                                reportId: reportId
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

            } else if viewModel.isLoading {

                ProgressView("Loading report...")

            } else {

                ContentUnavailableView(
                    "Report Unavailable",
                    systemImage: "doc.questionmark"
                )
            }
        }
        .navigationTitle("Report Details")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: reportId) {
            await viewModel.load(reportId: reportId)
        }

        .confirmationDialog(
            "Dismiss this report?",
            isPresented: $showDismissConfirmation,
            titleVisibility: .visible
        ) {

            Button(
                "Dismiss Report",
                role: .destructive
            ) {

                Task {

                    let succeeded = await viewModel.perform(
                        reportId: reportId,
                        action: .dismiss,
                        note: cleanedNote
                    )

                    if succeeded {
                        reviewNote = ""
                    }
                }
            }

            Button("Cancel", role: .cancel) { }

        } message: {

            Text(
                "Your decision and review note will be recorded in the audit history."
            )
        }
    }

    // MARK: - Report Content

    private func reportContent(
        _ report: ModerationReportDetail
    ) -> some View {

        Form {

            Section("Status") {

                LabeledContent(
                    "Current Status",
                    value: report.status.capitalized
                )

                LabeledContent(
                    "Submitted",
                    value: report.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )

                if let reviewerId = report.reviewerId {

                    VStack(alignment: .leading, spacing: 4) {

                        Text("Reviewer")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(reviewerId.uuidString)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            Section("Reported Content") {

                LabeledContent(
                    "Type",
                    value: report.targetType.capitalized
                )

                LabeledContent(
                    "Author",
                    value: "@\(report.evidenceUsername ?? "unknown")"
                )

                Text(
                    report.evidenceText ?? "No evidence snapshot."
                )
                .font(.body)
                .textSelection(.enabled)
            }

            Section("Report Reason") {

                Text(report.reasonTitle)
                    .fontWeight(.medium)

                if let explanation = report.explanation {

                    Text(explanation)
                        .textSelection(.enabled)

                } else {

                    Text("No additional explanation.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Identifiers") {

                identifierRow(
                    "Report ID",
                    value: report.id
                )

                identifierRow(
                    "Reporter ID",
                    value: report.reporterId
                )

                identifierRow(
                    "Reported User ID",
                    value: report.subjectUserId
                )

                identifierRow(
                    "Target ID",
                    value: report.targetId
                )
            }

            // MARK: - Review Actions

            Section("Review Actions") {

                if report.status == "pending" {

                    Button {

                        Task {

                            _ = await viewModel.perform(
                                reportId: reportId,
                                action: .claim
                            )
                        }

                    } label: {

                        Label(
                            "Claim for Review",
                            systemImage: "hand.raised"
                        )
                    }
                    .disabled(viewModel.isUpdating)

                } else if report.status == "reviewing" {

                    if viewModel.isCurrentReviewer {

                        Button {

                            Task {

                                _ = await viewModel.perform(
                                    reportId: reportId,
                                    action: .release
                                )
                            }

                        } label: {

                            Label(
                                "Release to Queue",
                                systemImage: "arrow.uturn.backward"
                            )
                        }
                        .disabled(viewModel.isUpdating)

                        reviewNoteEditor(
                            instruction:
                                "Explain why this report should be dismissed."
                        )

                        Button(
                            "Dismiss Report",
                            role: .destructive
                        ) {
                            showDismissConfirmation = true
                        }
                        .disabled(
                            !isNoteValid ||
                            viewModel.isUpdating
                        )

                    } else {

                        Text(
                            "This report is assigned to another moderator."
                        )
                        .foregroundStyle(.secondary)
                    }

                } else if report.status == "dismissed" {

                    if let note = report.resolutionNote {

                        Text("Previous Resolution")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(note)
                            .textSelection(.enabled)
                    }

                    reviewNoteEditor(
                        instruction:
                            "Explain why this report should be reopened."
                    )

                    Button {

                        Task {

                            let succeeded = await viewModel.perform(
                                reportId: reportId,
                                action: .reopen,
                                note: cleanedNote
                            )

                            if succeeded {
                                reviewNote = ""
                            }
                        }

                    } label: {

                        Label(
                            "Reopen Report",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .disabled(
                        !isNoteValid ||
                        viewModel.isUpdating
                    )

                } else {

                    Text(
                        "This report cannot be changed in Batch 2."
                    )
                    .foregroundStyle(.secondary)
                }

                if viewModel.isUpdating {

                    ProgressView("Saving decision...")
                }
            }

            // MARK: - Audit History

            Section("Review History") {

                if viewModel.history.isEmpty {

                    Text("No review actions recorded yet.")
                        .foregroundStyle(.secondary)

                } else {

                    ForEach(viewModel.history) { event in

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            HStack {

                                Text(event.action.capitalized)
                                    .fontWeight(.semibold)

                                Spacer()

                                Text(
                                    event.createdAt,
                                    style: .relative
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Text(
                                "\(event.previousStatus.capitalized) → \(event.newStatus.capitalized)"
                            )
                            .font(.caption)

                            if let note = event.note {

                                Text(note)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }

                            Text(
                                "Moderator: \(event.moderatorId.uuidString)"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = viewModel.errorMessage {

                Section {

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)

                    Button("Retry Loading") {

                        Task {
                            await viewModel.load(
                                reportId: reportId
                            )
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isUpdating)
    }

    // MARK: - Note Editor

    private func reviewNoteEditor(
        instruction: String
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            Text(instruction)
                .font(.subheadline)

            TextField(
                "Review note",
                text: $reviewNote,
                axis: .vertical
            )
            .lineLimit(3...6)
            .disabled(viewModel.isUpdating)

            HStack {

                Text("Required: 5–1000 characters")

                Spacer()

                Text("\(cleanedNote.count)/1000")
            }
            .font(.caption)
            .foregroundStyle(
                cleanedNote.count > 1000
                ? Color.red
                : Color.secondary
            )
        }
    }

    // MARK: - Identifier Display

    private func identifierRow(
        _ label: String,
        value: UUID
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.uuidString)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
