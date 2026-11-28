//
//  SuggestionListView.swift
//  Rawdea
//

import SwiftUI

/// The owner's waiting suggestions, or the viewer's own.
struct SuggestionListView: View {

    @StateObject private var viewModel: SuggestionListViewModel
    @State private var reportTarget: ReportTarget?
    @State private var blockCandidate: ProjectSuggestion?

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    init(scope: SuggestionListViewModel.Scope) {
        _viewModel = StateObject(
            wrappedValue: SuggestionListViewModel(scope: scope)
        )
    }

    private var isReview: Bool {
        if case .review = viewModel.scope { return true }
        return false
    }

    var body: some View {

        List {

            if !viewModel.hasLoaded {

                if let error = viewModel.errorMessage {
                    RawdeaEmptyState(
                        symbol: "exclamationmark.circle",
                        title: "Couldn't load suggestions",
                        message: error,
                        actionTitle: "Try Again"
                    ) {
                        Task { await viewModel.load() }
                    }
                    .row()
                } else {
                    RawdeaLoadingIndicator("Loading suggestions...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RawdeaSpacing.xl)
                        .row()
                }

            } else if viewModel.suggestions.isEmpty {

                RawdeaEmptyState(
                    symbol: "tray",
                    title: isReview ? "Nothing waiting" : "No suggestions yet",
                    message: isReview
                        ? "Followers' suggestions appear here for you to approve or decline."
                        : "Suggestions you send to Projects appear here."
                )
                .row()

            } else {

                ForEach(viewModel.suggestions) { suggestion in
                    card(suggestion)
                        .row()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .navigationTitle(isReview ? "Suggestions" : "Your suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .rawdeaRefreshable { await viewModel.load() }
        .sheet(item: $reportTarget) { ReportContentView(target: $0) }
        .confirmationDialog(
            "Block this person?",
            isPresented: Binding(
                get: { blockCandidate != nil },
                set: { if !$0 { blockCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: blockCandidate
        ) { suggestion in
            Button("Block", role: .destructive) {
                Task { await viewModel.block(suggestion) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { _ in
            Text("You won't see each other, and their waiting suggestions are removed.")
        }
        .alert(
            "Couldn't complete action",
            isPresented: Binding(
                get: { viewModel.hasLoaded && viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func card(_ suggestion: ProjectSuggestion) -> some View {

        RawdeaActivitySurface {

            VStack(alignment: .leading, spacing: RawdeaSpacing.xs) {

                HStack(alignment: .top, spacing: RawdeaSpacing.xs) {

                    VStack(alignment: .leading, spacing: RawdeaSpacing.xxs) {

                        Text(title(of: suggestion))
                            .font(RawdeaTypography.authorName)
                            .foregroundStyle(RawdeaPalette.primaryText)

                        Text("\(suggestion.kind.title) · \(PostRowView.shortAge(of: suggestion.createdAt, at: .now))\(isReview ? "" : " · \(suggestion.status.title)")")
                            .font(RawdeaTypography.metadata)
                            .foregroundStyle(RawdeaPalette.secondaryText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    if isReview {
                        menu(suggestion)
                    }
                }

                Text(suggestion.content)
                    .font(RawdeaTypography.postBody)
                    .foregroundStyle(RawdeaPalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                actions(suggestion)
            }
        }
    }

    private func title(of suggestion: ProjectSuggestion) -> String {
        if isReview {
            return suggestion.author?.username ?? "Someone"
        }
        return suggestion.project?.name ?? "A Project"
    }

    private func menu(_ suggestion: ProjectSuggestion) -> some View {

        Menu {
            Button("Open profile", systemImage: "person") {
                openPostRoute?(.author(suggestion.userId))
            }
            Button("Report", systemImage: "flag") {
                reportTarget = .account(suggestion.userId)
            }
            Button("Block", systemImage: "hand.raised", role: .destructive) {
                blockCandidate = suggestion
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(RawdeaPalette.secondaryText)
                .frame(
                    width: RawdeaSpacing.minimumTouchTarget,
                    height: RawdeaSpacing.minimumTouchTarget
                )
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Suggestion options")
    }

    @ViewBuilder
    private func actions(_ suggestion: ProjectSuggestion) -> some View {

        let isBusy = viewModel.busyId == suggestion.id

        if isReview {

            RawdeaWrapLayout(spacing: RawdeaSpacing.xs) {
                RawdeaPillButton(title: "Approve", isPrimary: true, isWorking: isBusy) {
                    Task { await viewModel.decide(suggestion, approve: true) }
                }
                RawdeaPillButton(title: "Decline") {
                    Task { await viewModel.decide(suggestion, approve: false) }
                }
            }
            .disabled(viewModel.busyId != nil)

        } else if suggestion.status == .waiting {

            RawdeaPillButton(title: "Withdraw", isWorking: isBusy) {
                Task { await viewModel.withdraw(suggestion) }
            }
            .disabled(viewModel.busyId != nil)

        } else if let postId = suggestion.postId {

            RawdeaPillButton(title: "View post") {
                openPostRoute?(.discussion(postId))
            }
        }
    }
}

private extension View {

    func row() -> some View {
        listRowInsets(
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
}
