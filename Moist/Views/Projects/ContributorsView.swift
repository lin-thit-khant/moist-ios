//
//  ContributorsView.swift
//  Rawdea
//

import SwiftUI

/// The owner manages who writes in a Project.
struct ContributorsView: View {

    @StateObject private var viewModel: ContributorsViewModel
    @State private var removal: Removal?

    @Environment(\.rawdeaOpenPostRoute) private var openPostRoute

    private struct Removal {
        let member: ProjectMember
        let hidePosts: Bool

        var name: String { member.person?.username ?? "this person" }
    }

    init(projectId: UUID) {
        _viewModel = StateObject(
            wrappedValue: ContributorsViewModel(projectId: projectId)
        )
    }

    var body: some View {

        List {

            if !viewModel.hasLoaded {

                if let error = viewModel.errorMessage {
                    RawdeaEmptyState(
                        symbol: "exclamationmark.circle",
                        title: "Couldn't load contributors",
                        message: error,
                        actionTitle: "Try Again"
                    ) {
                        Task { await viewModel.load() }
                    }
                    .plainRow()
                } else {
                    RawdeaLoadingIndicator("Loading contributors...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, RawdeaSpacing.xl)
                        .plainRow()
                }

            } else {

                heading("Contributors · \(viewModel.places.count) of \(ProjectMember.limit)")

                if viewModel.places.isEmpty {
                    note("Nobody yet. Contributors post notes, questions and progress. Decisions and stages stay yours.")
                }

                ForEach(viewModel.places) { member in
                    memberRow(member)
                }

                heading("Can be invited")

                if viewModel.candidates.isEmpty {
                    note("People appear here after you approve one of their suggestions.")
                } else if viewModel.isFull {
                    note("All 5 places are taken. Remove someone to invite another person.")
                }

                ForEach(viewModel.candidates) { candidate in
                    candidateRow(candidate)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RawdeaPalette.canvas.ignoresSafeArea())
        .navigationTitle("Contributors")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .rawdeaRefreshable { await viewModel.load() }
        .confirmationDialog(
            removal.map {
                $0.hidePosts
                    ? "Remove \($0.name) and hide their posts?"
                    : "Remove \($0.name)?"
            } ?? "",
            isPresented: Binding(
                get: { removal != nil },
                set: { if !$0 { removal = nil } }
            ),
            titleVisibility: .visible,
            presenting: removal
        ) { choice in
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.remove(
                        userId: choice.member.userId,
                        hidePosts: choice.hidePosts
                    )
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { choice in
            Text(choice.hidePosts
                ? "Use this for abuse. Their posts in this Project are hidden from everyone else."
                : "They can no longer post here. Their posts stay.")
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

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(RawdeaTypography.secondary.weight(.medium))
            .foregroundStyle(RawdeaPalette.secondaryText)
            .accessibilityAddTraits(.isHeader)
            .plainRow()
    }

    private func note(_ text: String) -> some View {
        RawdeaNoteDetail(text)
            .plainRow()
    }

    private func person(
        id: UUID,
        name: String,
        detail: String
    ) -> some View {

        Button {
            openPostRoute?(.author(id))
        } label: {
            HStack(spacing: RawdeaSpacing.sm) {
                RawdeaInitialAvatar(name: name)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(RawdeaTypography.authorName)
                        .foregroundStyle(RawdeaPalette.primaryText)
                    Text(detail)
                        .font(RawdeaTypography.metadata)
                        .foregroundStyle(RawdeaPalette.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: RawdeaSpacing.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens profile")
    }

    private func memberRow(_ member: ProjectMember) -> some View {

        let name = member.person?.username ?? "someone"

        return HStack(spacing: RawdeaSpacing.xs) {

            person(
                id: member.userId,
                name: name,
                detail: member.status == .active ? "Contributor" : "Invited"
            )

            if viewModel.busyId == member.userId {
                ProgressView()
            } else {
                Menu {
                    Button(
                        member.status == .active ? "Remove" : "Cancel invitation",
                        systemImage: "person.badge.minus"
                    ) {
                        removal = Removal(member: member, hidePosts: false)
                    }
                    Button("Remove and hide posts", systemImage: "eye.slash", role: .destructive) {
                        removal = Removal(member: member, hidePosts: true)
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
                .disabled(viewModel.busyId != nil)
                .accessibilityLabel("Options for \(name)")
            }
        }
        .plainRow()
    }

    private func candidateRow(_ candidate: ContributorCandidate) -> some View {

        RawdeaWrapLayout(spacing: RawdeaSpacing.xs) {

            person(
                id: candidate.userId,
                name: candidate.username,
                detail: candidate.approvedCount == 1
                    ? "1 approved suggestion"
                    : "\(candidate.approvedCount) approved suggestions"
            )

            RawdeaPillButton(
                title: "Invite",
                isPrimary: true,
                isWorking: viewModel.busyId == candidate.userId
            ) {
                Task { await viewModel.invite(userId: candidate.userId) }
            }
            .disabled(viewModel.busyId != nil || viewModel.isFull)
            .opacity(viewModel.isFull ? 0.5 : 1)
            .accessibilityLabel("Invite \(candidate.username)")
        }
        .plainRow()
    }
}

extension View {

    /// A list row on the bare canvas.
    func plainRow() -> some View {
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
