//
//  ModerationSafetyInboxView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import SwiftUI

struct ModerationSafetyInboxView: View {

    @StateObject private var viewModel =
        SafetyInboxViewModel()

    @State private var selectedStatus:
        SafetyInboxStatus = .open

    @State private var selectedRequest:
        ModerationSafetyRequest?

    var body: some View {

        List {

            Section {

                Picker(
                    "Status",
                    selection: $selectedStatus
                ) {

                    ForEach(SafetyInboxStatus.allCases) { status in

                        Text(status.title)
                            .tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.isLoading {

                RawdeaLoadingIndicator("Loading support inbox...")

            } else if let error = viewModel.errorMessage {

                Section("Error") {

                    Text(error)
                        .foregroundStyle(.red)

                    Button("Retry") {

                        Task {
                            await viewModel.load(
                                status: selectedStatus
                            )
                        }
                    }
                }

            } else if viewModel.requests.isEmpty {

                ContentUnavailableView(
                    "No Requests",
                    systemImage: "tray",
                    description: Text(
                        "There are no requests with this status."
                    )
                )

            } else {

                Section("Requests") {

                    ForEach(viewModel.requests) { request in

                        Button {

                            selectedRequest = request

                        } label: {

                            VStack(
                                alignment: .leading,
                                spacing: 8
                            ) {

                                HStack {

                                    Text(
                                        request.kind.capitalized
                                    )
                                    .fontWeight(.semibold)

                                    Spacer()

                                    Text(
                                        request.createdAt,
                                        style: .relative
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Text(request.message)
                                    .lineLimit(3)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)

                                Text(request.status.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Safety Inbox")
        .navigationBarTitleDisplayMode(.inline)

        .task(id: selectedStatus) {

            await viewModel.load(
                status: selectedStatus
            )
        }

        .refreshable {

            await viewModel.load(
                status: selectedStatus
            )
        }

        .sheet(
            item: $selectedRequest,
            onDismiss: {

                Task {
                    await viewModel.load(
                        status: selectedStatus
                    )
                }
            }
        ) { request in

            SafetyRequestReviewView(
                request: request,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Review Request

private struct SafetyRequestReviewView: View {

    let request: ModerationSafetyRequest

    @ObservedObject var viewModel: SafetyInboxViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var response = ""

    private var cleanedResponse: String {
        response.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Request") {

                    LabeledContent(
                        "Type",
                        value: request.kind.capitalized
                    )

                    LabeledContent(
                        "Status",
                        value: request.status.capitalized
                    )

                    Text(request.message)
                        .textSelection(.enabled)
                }

                Section("Requester") {

                    Text(request.requesterId.uuidString)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                if request.status == "open" {

                    Section("Response") {

                        TextEditor(text: $response)
                            .frame(minHeight: 130)
                            .disabled(viewModel.isResponding)

                        Text(
                            "\(cleanedResponse.count)/2000 — minimum 10"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Button {

                            let submittedResponse = cleanedResponse

                            Task {

                                let success = await viewModel.resolve(
                                    requestId: request.id,
                                    response: submittedResponse
                                )

                                if success {
                                    dismiss()
                                }
                            }

                        } label: {

                            if viewModel.isResponding {

                                ProgressView("Sending response...")

                            } else {

                                Text("Resolve and Reply")
                            }
                        }
                        .disabled(
                            !(10...2000).contains(
                                cleanedResponse.count
                            )
                            || viewModel.isResponding
                        )
                    }

                } else if let existing = request.response {

                    Section("Previous Response") {

                        Text(existing)
                            .textSelection(.enabled)
                    }
                }

                if let error = viewModel.errorMessage {

                    Section {

                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Review Request")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .cancellationAction
                ) {

                    Button("Close") {
                        dismiss()
                    }
                    .disabled(viewModel.isResponding)
                }
            }

            .interactiveDismissDisabled(
                viewModel.isResponding
            )
        }
    }
}
