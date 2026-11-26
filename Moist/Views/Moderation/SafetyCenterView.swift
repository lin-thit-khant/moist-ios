//
//  SafetyCenterView.swift
//  Rawdea
//
//  Created by Lin Thit Khant on 20/11/2569 BE.
//


import SwiftUI

struct SafetyCenterView: View {

    @StateObject private var viewModel =
        SafetyCenterViewModel()

    @State private var selectedKind: SafetyRequestKind
    @State private var message = ""

    init(initialKind: SafetyRequestKind = .support) {
        _selectedKind = State(
            initialValue: initialKind
        )
    }

    private var cleanedMessage: String {
        message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private var canSubmit: Bool {
        (20...2000).contains(cleanedMessage.count)
        && !viewModel.isSubmitting
    }

    var body: some View {

        Form {

            Section("Safety Resources") {

                NavigationLink {

                    SafetyInformationView()

                } label: {

                    Label(
                        "Community Guidelines & Contact",
                        systemImage: "shield"
                    )
                }
            }

            Section("Contact Rawdea") {

                Picker(
                    "Request Type",
                    selection: $selectedKind
                ) {

                    ForEach(SafetyRequestKind.allCases) { kind in

                        Text(kind.title)
                            .tag(kind)
                    }
                }

                Text(
                    selectedKind == .appeal
                    ? "Explain the moderation decision you want reviewed. Include relevant context."
                    : "Describe the issue you need help with."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                TextEditor(text: $message)
                    .frame(minHeight: 140)
                    .disabled(viewModel.isSubmitting)

                HStack {

                    Text("20–2000 characters")

                    Spacer()

                    Text("\(cleanedMessage.count)/2000")
                }
                .font(.caption)
                .foregroundStyle(
                    cleanedMessage.count > 2000
                    ? Color.red
                    : Color.secondary
                )

                Button {

                    let submittedKind = selectedKind
                    let submittedMessage = cleanedMessage

                    Task {

                        let success = await viewModel.submit(
                            kind: submittedKind,
                            message: submittedMessage
                        )

                        if success {
                            message = ""
                        }
                    }

                } label: {

                    if viewModel.isSubmitting {
                        ProgressView("Submitting...")
                    } else {
                        Text("Submit Request")
                    }
                }
                .disabled(!canSubmit)

                Text(
                    "You can submit up to three support or appeal requests every 24 hours."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let success = viewModel.successMessage {

                Section {
                    Label(
                        success,
                        systemImage: "checkmark.circle"
                    )
                    .foregroundStyle(.green)
                }
            }

            if let error = viewModel.errorMessage {

                Section("Error") {

                    Text(error)
                        .foregroundStyle(.red)

                    Button("Refresh Requests") {
                        Task {
                            await viewModel.load()
                        }
                    }
                }
            }

            Section("My Requests") {

                if viewModel.isLoading {

                    RawdeaLoadingIndicator("Loading requests...")

                } else if viewModel.requests.isEmpty {

                    Text("You haven't submitted a request yet.")
                        .foregroundStyle(.secondary)

                } else {

                    ForEach(viewModel.requests) { request in

                        VStack(
                            alignment: .leading,
                            spacing: 8
                        ) {

                            HStack {

                                Text(request.kind.capitalized)
                                    .fontWeight(.semibold)

                                Spacer()

                                Text(request.status.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(request.message)
                                .font(.subheadline)
                                .textSelection(.enabled)

                            Text(
                                request.createdAt,
                                style: .date
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let response = request.response {

                                Divider()

                                Text("Rawdea Response")
                                    .fontWeight(.semibold)

                                Text(response)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }

        }
        .scrollContentBackground(.hidden)
        .background(
            RawdeaPalette.canvas
                .ignoresSafeArea()
        )
        .navigationTitle("Safety & Support")
        .navigationBarTitleDisplayMode(.inline)

        .task {
            await viewModel.load()
        }

        .rawdeaRefreshable {
            await viewModel.load()
        }
    }
}
