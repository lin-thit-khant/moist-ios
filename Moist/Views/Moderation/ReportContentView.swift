//
//  ReportContentView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 19/11/2569 BE.
//


import SwiftUI

struct ReportContentView: View {

    let target: ReportTarget

    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel =
        ReportViewModel()

    @State private var selectedReason: ReportReason = .spam

    @State private var explanation = ""

    // MARK: - Validation

    private var cleanedExplanation: String {
        explanation.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSubmit: Bool {

        guard !viewModel.isSubmitting,
              !viewModel.hasSubmitted,
              explanation.count <= 1000 else {
            return false
        }

        if selectedReason == .other {
            return !cleanedExplanation.isEmpty
        }

        return true
    }

    // MARK: - Body

    var body: some View {

        NavigationStack {

            Group {

                if viewModel.hasSubmitted {

                    successContent

                } else {

                    reportForm
                }
            }
            .navigationTitle(
                "Report \(target.displayName)"
            )
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .topBarLeading
                ) {

                    Button("Close") {
                        dismiss()
                    }
                    .disabled(viewModel.isSubmitting)
                }

                if !viewModel.hasSubmitted {

                    ToolbarItem(
                        placement: .topBarTrailing
                    ) {

                        Button("Submit") {

                            Task {

                                await viewModel.submit(
                                    target: target,
                                    reason: selectedReason,
                                    explanation: explanation
                                )
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSubmit)
                    }
                }
            }

            .interactiveDismissDisabled(
                viewModel.isSubmitting
            )

            .alert(
                "Couldn't Submit Report",
                isPresented: Binding(
                    get: {
                        viewModel.errorMessage != nil
                    },
                    set: { isPresented in

                        if !isPresented {
                            viewModel.clearError()
                        }
                    }
                )
            ) {

                Button("OK", role: .cancel) {
                    viewModel.clearError()
                }

            } message: {

                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Report Form

    private var reportForm: some View {

        Form {

            Section {

                Text(
                    """
                    Help us keep Rawdea safe.
                    Select the reason that best describes the problem.
                    """
                )
                .foregroundStyle(.secondary)

            }

            Section("Why are you reporting this?") {

                Picker(
                    "Reason",
                    selection: $selectedReason
                ) {

                    ForEach(ReportReason.allCases) { reason in

                        Text(reason.title)
                            .tag(reason)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {

                TextEditor(text: $explanation)
                    .frame(minHeight: 120)
                    .disabled(viewModel.isSubmitting)

                HStack {

                    Text(
                        selectedReason == .other
                        ? "Required for this reason"
                        : "Optional"
                    )

                    Spacer()

                    Text("\(explanation.count)/1000")
                }
                .font(.caption)
                .foregroundStyle(
                    explanation.count > 1000
                    ? Color.red
                    : Color.secondary
                )

            } header: {

                Text("Additional Details")

            } footer: {

                Text(
                    """
                    Explain what happened if more context would help us review the report. Avoid including unnecessary personal information.
                    """
                )
            }

            Section {

                Label(
                    "Reports are private.",
                    systemImage: "lock.shield"
                )
                .font(.subheadline)

                Text(
                    """
                    Submitting a report does not automatically remove content or block the account. Reports are reviewed for potential policy violations.
                    """
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if viewModel.isSubmitting {

                Section {

                    HStack {

                        Spacer()

                        ProgressView("Submitting report...")

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Success

    private var successContent: some View {

        VStack(spacing: 20) {

            Image(
                systemName: "checkmark.shield.fill"
            )
            .font(.system(size: 54))
            .foregroundStyle(.green)

            Text("Report Submitted")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                """
                Thank you for helping keep Rawdea safe.

                Your report has been received for moderation review.
                """
            )
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}
